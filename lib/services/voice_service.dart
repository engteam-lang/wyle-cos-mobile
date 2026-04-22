import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

typedef TranscriptCallback = void Function(String text);
typedef StateCallback      = void Function(String state);
typedef PartialCallback    = void Function(String partial);

/// Voice recording and text-to-speech service
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech  = SpeechToText();
  final FlutterTts   _tts     = FlutterTts();
  bool _speechAvailable       = false;
  bool _isListening           = false;

  // Completer kept alive for the entire duration speech is playing.
  // speak() awaits it so _isSpeaking stays true until speech actually ends.
  Completer<void>? _speakCompleter;

  Future<void> init() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {},
      onError:  (error) {},
    );

    await _tts.setLanguage('en-US');
    await _configureNaturalVoice();
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.85); // Fast — natural but brisk

    // Complete the completer when TTS finishes naturally
    _tts.setCompletionHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    // Also complete on cancel or error so we never get stuck
    _tts.setCancelHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
    _tts.setErrorHandler((_) {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });
  }

  /// Prefer a natural-sounding female English voice when available.
  Future<void> _configureNaturalVoice() async {
    try {
      final dynamic rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return;

      final voices = rawVoices.whereType<dynamic>().toList();
      Map<String, dynamic>? best;
      int bestScore = -1;

      for (final v in voices) {
        if (v is! Map) continue;
        final voice = v.map((k, value) => MapEntry('$k', value));

        final locale = (voice['locale'] ?? voice['language'] ?? '')
            .toString()
            .toLowerCase();
        if (!locale.startsWith('en')) continue;

        final name = (voice['name'] ?? '').toString().toLowerCase();
        final gender = (voice['gender'] ?? '').toString().toLowerCase();

        var score = 0;
        if (locale.startsWith('en-us')) score += 30;
        if (gender.contains('female')) score += 40;
        if (name.contains('female') ||
            name.contains('woman') ||
            name.contains('samantha') ||
            name.contains('zira') ||
            name.contains('aria') ||
            name.contains('jenny')) {
          score += 25;
        }
        if (name.contains('neural') ||
            name.contains('wavenet') ||
            name.contains('enhanced') ||
            name.contains('natural')) {
          score += 15;
        }

        if (score > bestScore) {
          bestScore = score;
          best = voice;
        }
      }

      if (best != null) {
        final selectedName = best['name']?.toString();
        final selectedLocale =
            (best['locale'] ?? best['language'])?.toString();
        await _tts.setVoice({
          if (selectedName != null) 'name': selectedName,
          if (selectedLocale != null) 'locale': selectedLocale,
        });
      }
    } catch (_) {
      // Keep defaults if voice enumeration is not supported on this device.
    }
  }

  bool get isListening => _isListening;
  bool get isAvailable => _speechAvailable;

  /// Start speech recognition.
  /// [onPartial] receives live partial words as the user speaks.
  /// Auto-stops after [silenceTimeout] of silence (default 3 s).
  Future<void> startListening(
    TranscriptCallback onResult,
    StateCallback onState, {
    PartialCallback? onPartial,
    Duration silenceTimeout = const Duration(seconds: 3),
  }) async {
    if (!_speechAvailable) {
      final ok = await _speech.initialize();
      if (!ok) {
        onState('error');
        return;
      }
      _speechAvailable = ok;
    }

    _isListening = true;
    onState('listening');

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          onState('idle');
          onResult(result.recognizedWords);
        } else if (onPartial != null) {
          // Live words while user is still speaking
          onPartial(result.recognizedWords);
        }
      },
      listenMode:     ListenMode.dictation,
      cancelOnError:  true,
      partialResults: true,
      pauseFor:       silenceTimeout, // auto-stop after N seconds of silence
    );
  }

  /// Stop speech recognition
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }

  /// Speak text aloud.
  /// Returns only when speech has fully completed (or been stopped).
  /// This keeps _isSpeaking = true for the full duration of playback.
  Future<void> speak(String text) async {
    // Cancel any in-progress speech first
    _speakCompleter?.complete();
    _speakCompleter = null;

    await _tts.stop();

    _speakCompleter = Completer<void>();
    await _tts.speak(text);

    // Wait here until the completion/cancel/error handler fires
    await _speakCompleter!.future;
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    // Manually complete in case the handler doesn't fire on this platform
    _speakCompleter?.complete();
    _speakCompleter = null;
  }

  bool get isSpeaking => false;
}
