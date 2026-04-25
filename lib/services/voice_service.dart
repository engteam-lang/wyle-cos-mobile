import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

typedef TranscriptCallback = void Function(String text);
typedef StateCallback      = void Function(String state);
typedef PartialCallback    = void Function(String partial);

/// Voice recording and text-to-speech service
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech  = SpeechToText();
  final FlutterTts   _tts     = FlutterTts();
  final AudioPlayer  _audioPlayer = AudioPlayer();
  
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

    // Initialize fallback native TTS
    await _tts.setLanguage('en-US');
    await _configureNaturalVoice();
    await _tts.setPitch(1.08);
    await _tts.setSpeechRate(0.46);

    // Complete the completer when native TTS finishes naturally
    _tts.setCompletionHandler(() {
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter?.complete();
      }
      _speakCompleter = null;
    });
    _tts.setCancelHandler(() {
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter?.complete();
      }
      _speakCompleter = null;
    });
    _tts.setErrorHandler((_) {
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter?.complete();
      }
      _speakCompleter = null;
    });

    // Complete the completer when cloud TTS finishes playing
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
          _speakCompleter?.complete();
        }
        _speakCompleter = null;
      }
    });
  }

  /// Prefer a natural, warm female English voice when available.
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
            name.contains('jenny') ||
            name.contains('alloy') ||
            name.contains('nova')) {
          score += 25;
        }
        if (name.contains('neural') ||
            name.contains('wavenet') ||
            name.contains('enhanced') ||
            name.contains('natural')) {
          score += 15;
        }
        if (name.contains('assistant') || name.contains('robot')) {
          score -= 30;
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
  /// Auto-stops after [silenceTimeout] of silence (default 8 s — long enough
  /// for natural pauses during brain-dump style speech).
  Future<void> startListening(
    TranscriptCallback onResult,
    StateCallback onState, {
    PartialCallback? onPartial,
    Duration silenceTimeout = const Duration(seconds: 8),
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
      pauseFor:       silenceTimeout,         // auto-stop after N s of silence
      listenFor:      const Duration(minutes: 3), // max session length
    );
  }

  /// Stop speech recognition
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }

  /// Speak text aloud using OpenAI TTS, with flutter_tts fallback.
  /// Returns only when speech has fully completed (or been stopped).
  /// This keeps _speakCompleter active for the full duration of playback.
  Future<void> speak(String text) async {
    // Cancel any in-progress speech first
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter?.complete();
    }
    _speakCompleter = null;

    await _tts.stop();
    await _audioPlayer.stop();

    _speakCompleter = Completer<void>();

    try {
      final apiKey = dotenv.env['EXPO_PUBLIC_OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("No OpenAI API key found. Falling back to native TTS.");
      }

      final url = Uri.parse('https://api.openai.com/v1/audio/speech');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': text,
          'voice': 'nova', // Human female voice
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_response.mp3');
        await file.writeAsBytes(response.bodyBytes);
        await _audioPlayer.setFilePath(file.path);
        await _audioPlayer.play();
      } else {
        throw Exception("OpenAI TTS failed with status ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("TTS Error: $e");
      // Fallback to native TTS if cloud TTS fails
      await _tts.speak(text);
    }

    // Wait here until the completion/cancel/error handler fires
    if (_speakCompleter != null) {
      await _speakCompleter!.future;
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _audioPlayer.stop();
    // Manually complete in case the handler doesn't fire on this platform
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter?.complete();
    }
    _speakCompleter = null;
  }

  bool get isSpeaking => _speakCompleter != null && !_speakCompleter!.isCompleted;
}
