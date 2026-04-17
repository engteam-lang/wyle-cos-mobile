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

  Future<void> init() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {},
      onError:  (error) {},
    );

    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.65); // Faster — was 0.5
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

  /// Speak text aloud
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  bool get isSpeaking => false;
}
