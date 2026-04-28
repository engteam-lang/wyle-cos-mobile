import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'buddy_api_service.dart';
import '../models/brain_dump_model.dart';

/// Result returned after the full Brain Dump pipeline completes.
class BrainDumpResult {
  final String transcript;
  final int    savedItemCount;
  const BrainDumpResult({
    required this.transcript,
    required this.savedItemCount,
  });
}

/// Handles the full voice → Brain Dump API pipeline for ALL platforms:
///
///   startRecording() → stopRecording() → processAudio()
///
/// Web:    AudioRecorder.start() records to an in-memory browser blob.
///         stop() returns a blob URL; we fetch the raw bytes with http.get()
///         (XHR can access same-origin blob URLs).
///         Produces audio/webm (Opus), which the Brain Dump API accepts.
///
/// Mobile: AudioRecorder.start() records to a temp .m4a file (AAC-LC).
///         stop() returns the file path; we read bytes directly.
///
/// NOTE:   startStream() is intentionally NOT used.  record_linux v0.7.x
///         does not implement startStream, causing compile errors on the
///         Linux CI runner when building the Android APK.
class BrainDumpService {
  BrainDumpService._();
  static final BrainDumpService instance = BrainDumpService._();

  AudioRecorder? _recorder;
  bool _isRecording = false;

  // ── Silence detection ──────────────────────────────────────────────────────
  /// Amplitude must exceed this to be treated as speech (dBFS).
  /// −20 dBFS ≈ 10 % of max volume — clearly above mic hiss and
  /// background noise (~−35 to −40 dBFS) but well within normal speech.
  static const double _speechThresholdDb = -20.0;

  /// Amplitude must stay below this for [_silenceDuration] to auto-stop.
  /// Using the same value: once speech drops below −20 the countdown starts.
  static const double _silenceThresholdDb = -20.0;

  static const Duration _silenceDuration = Duration(seconds: 3);

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer?                          _silenceTimer;
  bool                            _hasSpeechStarted = false;

  bool get isRecording => _isRecording;

  // ── Recording ──────────────────────────────────────────────────────────────

  /// Start recording.  Throws if microphone permission is denied.
  ///
  /// [onSilenceDetected] — called once after [_silenceDuration] of continuous
  /// silence so the caller can auto-stop the recording.  The callback fires on
  /// the main Dart isolate (Timer guarantee) and is only called while
  /// [isRecording] is still true.
  Future<void> startRecording({void Function()? onSilenceDetected}) async {
    _recorder ??= AudioRecorder();
    final ok = await _recorder!.hasPermission();
    if (!ok) throw Exception('Microphone permission denied');

    if (kIsWeb) {
      // Web: record 6.x requires an empty-string path on web;
      // the browser MediaRecorder stores audio in an internal blob.
      await _recorder!.start(
        const RecordConfig(
          encoder:     AudioEncoder.opus,   // → audio/webm;codecs=opus in Chrome
          sampleRate:  16000,
          numChannels: 1,
          bitRate:     64000,
        ),
        path: '',
      );
    } else {
      // Mobile: record to a temp .m4a file (AAC-LC)
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/bd_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(
          encoder:     AudioEncoder.aacLc,
          sampleRate:  16000,
          numChannels: 1,
          bitRate:     64000,
        ),
        path: path,
      );
    }
    _isRecording = true;

    // ── Silence detection ──────────────────────────────────────────────────
    if (onSilenceDetected != null) {
      _cancelSilenceDetection(); // clear any leftover state from a previous call
      _hasSpeechStarted = false; // wait for first speech before tracking pauses

      _amplitudeSub = _recorder!
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (amp.current > _speechThresholdDb) {
          // ── User is clearly speaking ───────────────────────────────────
          // Mark speech started and cancel the silence countdown.
          _hasSpeechStarted = true;
          _silenceTimer?.cancel();
          _silenceTimer = null;
        } else if (_hasSpeechStarted && _silenceTimer == null) {
          // ── Amplitude dropped below speech threshold AFTER speech started
          // Arm the 3-second countdown.  If the user speaks again before it
          // fires the block above cancels and resets it.
          _silenceTimer = Timer(_silenceDuration, () {
            if (_isRecording) onSilenceDetected();
          });
        }
        // _hasSpeechStarted == false  → user hasn't spoken yet, do nothing.
        // _silenceTimer != null       → countdown already running, let it run.
      });
    }
  }

  /// Cancel silence-detection timers and stream.
  /// Called automatically by [stopRecording] and [cancelRecording].
  void _cancelSilenceDetection() {
    _silenceTimer?.cancel();
    _amplitudeSub?.cancel();
    _silenceTimer     = null;
    _amplitudeSub     = null;
    _hasSpeechStarted = false;
  }

  /// Public version so the caller can cancel if the user taps Stop manually
  /// before the timer fires (avoids a redundant second call to _stopRecording).
  void stopSilenceDetection() => _cancelSilenceDetection();

  /// Stop recording and return the raw audio bytes.
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording || _recorder == null) return null;
    _cancelSilenceDetection(); // ensure timer doesn't fire after stop

    final result = await _recorder!.stop();
    _isRecording = false;
    if (result == null) return null;

    if (kIsWeb) {
      // On web stop() returns a blob URL ("blob:https://…").
      // http.get() uses XHR under the hood, which can fetch same-origin
      // blob URLs — no dart:html required.
      try {
        final response = await http.get(Uri.parse(result));
        if (response.statusCode != 200) return null;
        return response.bodyBytes;
      } catch (_) {
        return null;
      }
    } else {
      // Mobile: result is a file-system path
      final file = File(result);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      try { await file.delete(); } catch (_) {}
      return bytes;
    }
  }

  /// Cancel without saving.
  Future<void> cancelRecording() async {
    _cancelSilenceDetection();
    if (_isRecording && _recorder != null) {
      await _recorder!.cancel();
      _isRecording = false;
    }
  }

  // ── Full pipeline ──────────────────────────────────────────────────────────

  /// Upload [audioBytes] → poll until done → commit all items.
  /// Returns transcript text and number of action items saved.
  Future<BrainDumpResult> processAudio(Uint8List audioBytes) async {
    // Platform-specific format:
    //   Web    → audio/webm  (Opus / MediaRecorder)
    //   Mobile → audio/mp4   (AAC-LC in .m4a container)
    final filename = kIsWeb ? 'recording.webm' : 'recording.m4a';
    final mimeType = kIsWeb ? 'audio/webm'     : 'audio/mp4';

    // 1. Create job
    final job = await BuddyApiService.instance.createBrainDumpJob();

    // 2. Upload audio
    BrainDumpJobModel current =
        await BuddyApiService.instance.uploadBrainDumpAudio(
      jobId:      job.id,
      audioBytes: audioBytes,
      filename:   filename,
      mimeType:   mimeType,
    );

    // 3. Poll until status is awaiting_review / done / failed  (max 60 s)
    int attempts = 0;
    while (current.isPending && attempts < 30) {
      await Future.delayed(const Duration(seconds: 2));
      current = await BuddyApiService.instance.getBrainDumpJob(job.id);
      attempts++;
    }

    if (current.isFailed) {
      throw Exception(
          'Voice processing failed: ${current.errorMessage ?? 'unknown error'}');
    }

    final transcript = current.transcript ?? '';

    // 4. Commit all extracted items
    int savedCount = 0;
    if (current.isComplete) {
      try {
        final result = await BuddyApiService.instance.commitBrainDumpJob(
          jobId:       job.id,
          itemIndices: null, // null = commit everything
        );
        savedCount = result.createdIds.length;
      } catch (_) {
        // Commit errors are non-fatal — transcript is still returned
      }
    }

    return BrainDumpResult(
      transcript:     transcript,
      savedItemCount: savedCount,
    );
  }
}
