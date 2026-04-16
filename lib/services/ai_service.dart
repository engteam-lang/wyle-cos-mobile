import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Unified AI caller: Claude → Groq → Gemini fallback chain
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static String get _anthropicKey => dotenv.env['EXPO_PUBLIC_ANTHROPIC_API_KEY'] ?? '';
  static String get _groqKey      => dotenv.env['EXPO_PUBLIC_GROQ_API_KEY']      ?? '';
  static String get _geminiKey    => dotenv.env['EXPO_PUBLIC_GEMINI_API_KEY']    ?? '';

  /// Call Claude with a system prompt and user message. Falls back to Groq, then Gemini.
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    String model = 'claude-opus-4-6',
    int maxTokens = 1024,
  }) async {
    // Try Claude first
    if (_anthropicKey.isNotEmpty) {
      try {
        return await _callClaude(
          systemPrompt: systemPrompt,
          userMessage:  userMessage,
          model:        model,
          maxTokens:    maxTokens,
        );
      } catch (_) {}
    }

    // Fallback: Groq
    if (_groqKey.isNotEmpty) {
      try {
        return await _callGroq(
          systemPrompt: systemPrompt,
          userMessage:  userMessage,
          maxTokens:    maxTokens,
        );
      } catch (_) {}
    }

    // Fallback: Gemini
    if (_geminiKey.isNotEmpty) {
      try {
        return await _callGemini(
          systemPrompt: systemPrompt,
          userMessage:  userMessage,
        );
      } catch (_) {}
    }

    throw Exception('All AI providers unavailable. Please check your API keys.');
  }

  Future<String> _callClaude({
    required String systemPrompt,
    required String userMessage,
    required String model,
    required int maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':          _anthropicKey,
        'anthropic-version':  '2023-06-01',
      },
      body: jsonEncode({
        'model':      model,
        'max_tokens': maxTokens,
        'system':     systemPrompt,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  Future<String> _callGroq({
    required String systemPrompt,
    required String userMessage,
    required int maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $_groqKey',
      },
      body: jsonEncode({
        'model':      'llama-3.3-70b-versatile',
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user',   'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
  }) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': '$systemPrompt\n\n$userMessage'},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  /// Parse JSON from AI response — strips markdown code fences if present
  static Map<String, dynamic>? parseJsonResponse(String text) {
    String clean = text.trim();
    // Strip ```json ... ``` or ``` ... ```
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fencePattern.firstMatch(clean);
    if (match != null) {
      clean = match.group(1)!.trim();
    }
    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Parse list of JSON objects from AI response
  static List<Map<String, dynamic>>? parseJsonArray(String text) {
    String clean = text.trim();
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fencePattern.firstMatch(clean);
    if (match != null) {
      clean = match.group(1)!.trim();
    }
    try {
      final list = jsonDecode(clean) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
