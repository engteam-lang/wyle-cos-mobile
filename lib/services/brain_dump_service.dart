import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
/// Web:    Uses AudioRecorder.startStream() so chunks arrive as a
///         Stream<Uint8List>; the browser's MediaRecorder produces
///         audio/webm (Opus codec) which the API accepts natively.
///
/// Mobile: Records to a temp .m4a file (AAC-LC), then reads bytes on stop.
class BrainDumpService {
  BrainDumpService._();
  static final BrainDumpService instance = BrainDumpService._();

  AudioRecorder? _recorder;
  bool _isRecording = false;

  // Web stream recording state
  StreamSubscription<Uint8List>? _streamSub;
  final List<Uint8List> _webChunks = [];

  bool get isRecording => _isRecording;

  // ── Recording ──────────────────────────────────────────────────────────────

  /// Start recording.  Throws if microphone permission is denied.
  Future<void> startRecording() async {
    _recorder ??= AudioRecorder();
    final ok = await _recorder!.hasPermission();
    if (!ok) throw Exception('Microphone permission denied');

    if (kIsWeb) {
      // Web: stream raw bytes from the browser MediaRecorder
      // AudioEncoder.opus → audio/webm;codecs=opus (Chrome) — matches
      // the .webm format the Brain Dump API accepts.
      _webChunks.clear();
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder:     AudioEncoder.opus,
          sampleRate:  16000,
          numChannels: 1,
          bitRate:     64000,
        ),
      );
      _streamSub = stream.listen(
        (chunk) => _webChunks.add(chunk),
        cancelOnError: true,
      );
    } else {
      // Mobile: record to a temp .m4a file
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
  }

  /// Stop recording and return the raw audio bytes.
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording || _recorder == null) return null;

    if (kIsWeb) {
      // Stopping the recorder flushes any remaining chunks to the stream
      // before it closes, so we await stop() first, then cancel the sub.
      await _recorder!.stop();
      await _streamSub?.cancel();
      _streamSub = null;
      _isRecording = false;

      if (_webChunks.isEmpty) return null;

      // Assemble the individual MediaRecorder chunks into one Uint8List.
      // Together they form a valid WebM container the API can decode.
      final totalLen = _webChunks.fold(0, (sum, c) => sum + c.length);
      final result   = Uint8List(totalLen);
      int offset = 0;
      for (final chunk in _webChunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      _webChunks.clear();
      return result;
    } else {
      final path = await _recorder!.stop();
      _isRecording = false;
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      try { await file.delete(); } catch (_) {}
      return bytes;
    }
  }

  /// Cancel without saving.
  Future<void> cancelRecording() async {
    if (_isRecording && _recorder != null) {
      await _streamSub?.cancel();
      _streamSub = null;
      _webChunks.clear();
      await _recorder!.cancel();
      _isRecording = false;
    }
  }

  // ── Full pipeline ──────────────────────────────────────────────────────────

  /// Upload [audioBytes] → poll until done → commit all items.
  /// Returns transcript text and number of action items saved.
  Future<BrainDumpResult> processAudio(Uint8List audioBytes) async {
    // Platform-specific format:
    //   Web    → audio/webm  (MediaRecorder / Opus codec)
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
