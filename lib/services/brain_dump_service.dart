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

/// Handles the full voice → Brain Dump API pipeline:
///   startRecording() → stopRecording() → processAudio()
///
/// Only available on mobile (Android/iOS).  kIsWeb callers must use
/// VoiceService (speech_to_text) instead.
class BrainDumpService {
  BrainDumpService._();
  static final BrainDumpService instance = BrainDumpService._();

  AudioRecorder? _recorder;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  // ── Recording ──────────────────────────────────────────────────────────────

  /// Start recording to a temp file.  Throws if permission is denied.
  Future<void> startRecording() async {
    if (kIsWeb) throw UnsupportedError('Brain dump not supported on web');
    _recorder ??= AudioRecorder();
    final ok = await _recorder!.hasPermission();
    if (!ok) throw Exception('Microphone permission denied');

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
    _isRecording = true;
  }

  /// Stop recording and return the raw audio bytes.
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording || _recorder == null) return null;
    final path = await _recorder!.stop();
    _isRecording = false;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try { await file.delete(); } catch (_) {}
    return bytes;
  }

  /// Cancel without saving.
  Future<void> cancelRecording() async {
    if (_isRecording && _recorder != null) {
      await _recorder!.cancel();
      _isRecording = false;
    }
  }

  // ── Full pipeline ──────────────────────────────────────────────────────────

  /// Upload [audioBytes] → poll until done → commit all items.
  /// Returns transcript text and number of action items saved.
  Future<BrainDumpResult> processAudio(Uint8List audioBytes) async {
    // 1. Create job
    final job = await BuddyApiService.instance.createBrainDumpJob();

    // 2. Upload audio
    BrainDumpJobModel current =
        await BuddyApiService.instance.uploadBrainDumpAudio(
      jobId:      job.id,
      audioBytes: audioBytes,
      filename:   'recording.m4a',
      mimeType:   'audio/mp4',
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
