import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Unified AI caller: Claude → Groq → Gemini fallback chain
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static String get _anthropicKey => dotenv.env['EXPO_PUBLIC_ANTHROPIC_API_KEY'] ?? '';
  static String get _groqKey      => dotenv.env['EXPO_PUBLIC_GROQ_API_KEY']      ?? '';
  static String get _geminiKey    => dotenv.env['EXPO_PUBLIC_GEMINI_API_KEY']    ?? '';

  /// On web the browser blocks direct calls to Claude/Groq (CORS).
  /// Run `dart run server/proxy.dart` in your Codespace and set
  /// PROXY_URL=https://<codespace>-8081.app.github.dev in .env.
  /// On native (iOS/Android) this value is ignored — APIs are called directly.
  static String get _proxyUrl {
    final raw = dotenv.env['PROXY_URL'] ?? 'http://localhost:8081';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Returns the correct URL for a given AI endpoint.
  /// On web, routes through the local proxy to avoid CORS errors.
  static String _url(String directUrl, String proxyPath) =>
      kIsWeb ? '$_proxyUrl$proxyPath' : directUrl;

  // ── Text-only completion ─────────────────────────────────────────────────────

  /// Claude → Groq → Gemini fallback for plain text conversation.
  Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    String model    = 'claude-opus-4-6',
    int    maxTokens = 1024,
  }) async {
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
    if (_groqKey.isNotEmpty) {
      try {
        return await _callGroq(
          systemPrompt: systemPrompt,
          userMessage:  userMessage,
          maxTokens:    maxTokens,
        );
      } catch (_) {}
    }
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

  // ── File-aware completion ────────────────────────────────────────────────────

  /// Send a file (image / PDF / plain-text) alongside a message.
  ///
  /// Supported MIME types that get passed as binary:
  ///   image/*          → Claude vision / Gemini vision
  ///   application/pdf  → Claude document API / Gemini inline
  ///
  /// Plain-text files (text/*, csv, md …) are decoded and sent inline so
  /// Groq can also participate in the fallback chain.
  Future<String> completeWithFile({
    required String    systemPrompt,
    required String    userMessage,
    required Uint8List fileBytes,
    required String    mimeType,
    String model    = 'claude-opus-4-6',
    int    maxTokens = 1500,
  }) async {
    final isImage   = mimeType.startsWith('image/');
    final isPdf     = mimeType == 'application/pdf';
    final isText    = mimeType.startsWith('text/');

    // Plain-text files: decode and append inline → all three providers work
    if (isText) {
      final textContent = utf8.decode(fileBytes, allowMalformed: true);
      final combined = '$userMessage\n\n--- File contents ---\n$textContent';
      return complete(
        systemPrompt: systemPrompt,
        userMessage:  combined,
        model:        model,
        maxTokens:    maxTokens,
      );
    }

    // Binary files (image / PDF): Claude first, Gemini as fallback
    if (isImage || isPdf) {
      if (_anthropicKey.isNotEmpty) {
        try {
          return await _callClaudeWithFile(
            systemPrompt: systemPrompt,
            userMessage:  userMessage,
            fileBytes:    fileBytes,
            mimeType:     mimeType,
            model:        model,
            maxTokens:    maxTokens,
          );
        } catch (_) {}
      }
      if (_geminiKey.isNotEmpty) {
        // _callGeminiWithFile already retries once on 429
        return await _callGeminiWithFile(
          systemPrompt: systemPrompt,
          userMessage:  userMessage,
          fileBytes:    fileBytes,
          mimeType:     mimeType,
        );
      }
      throw Exception(
          'No vision-capable AI provider available. Add a Claude or Gemini API key.');
    }

    // Unsupported binary format — tell the user gracefully
    return "I can read images and PDFs directly. For other file types "
        "(Word, Excel, PowerPoint), please copy and paste the text content "
        "into the chat and I'll analyse it for you.";
  }

  // ── Claude (text) ────────────────────────────────────────────────────────────

  Future<String> _callClaude({
    required String systemPrompt,
    required String userMessage,
    required String model,
    required int    maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse(_url('https://api.anthropic.com/v1/messages', '/claude')),
      headers: {
        'Content-Type':     'application/json',
        'x-api-key':         _anthropicKey,
        'anthropic-version': '2023-06-01',
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
    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  // ── Claude (image / PDF) ─────────────────────────────────────────────────────

  Future<String> _callClaudeWithFile({
    required String    systemPrompt,
    required String    userMessage,
    required Uint8List fileBytes,
    required String    mimeType,
    required String    model,
    required int       maxTokens,
  }) async {
    final b64 = base64Encode(fileBytes);

    // Build the multimodal content block
    final Map<String, dynamic> fileBlock = mimeType.startsWith('image/')
        ? {
            'type': 'image',
            'source': {
              'type':       'base64',
              'media_type': mimeType,
              'data':        b64,
            },
          }
        : {
            // PDF — requires anthropic-beta header
            'type': 'document',
            'source': {
              'type':       'base64',
              'media_type': 'application/pdf',
              'data':        b64,
            },
          };

    final response = await http.post(
      Uri.parse(_url('https://api.anthropic.com/v1/messages', '/claude')),
      headers: {
        'Content-Type':     'application/json',
        'x-api-key':         _anthropicKey,
        'anthropic-version': '2023-06-01',
        // PDF support beta header (ignored for image requests)
        'anthropic-beta':    'pdfs-2024-09-25',
      },
      body: jsonEncode({
        'model':      model,
        'max_tokens': maxTokens,
        'system':     systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': [
              fileBlock,
              {'type': 'text', 'text': userMessage},
            ],
          },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Claude file API error: ${response.statusCode} ${response.body}');
    }
    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }

  // ── Groq (text only) ─────────────────────────────────────────────────────────

  Future<String> _callGroq({
    required String systemPrompt,
    required String userMessage,
    required int    maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse(_url('https://api.groq.com/openai/v1/chat/completions', '/groq')),
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

  // ── Gemini (text) ────────────────────────────────────────────────────────────

  /// Calls Gemini directly (supports browser CORS natively).
  /// Retries once after 3 s on 429 (free-tier rate limit).
  Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
  }) async {
    return _callGeminiRaw(systemPrompt: systemPrompt, userMessage: userMessage);
  }

  Future<String> _callGeminiRaw({
    required String systemPrompt,
    required String userMessage,
    int attempt = 0,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';
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
    // 429 = rate limited — wait 3 s and retry once
    if (response.statusCode == 429 && attempt == 0) {
      await Future.delayed(const Duration(seconds: 3));
      return _callGeminiRaw(
          systemPrompt: systemPrompt, userMessage: userMessage, attempt: 1);
    }
    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ── Gemini (image / PDF) ─────────────────────────────────────────────────────

  Future<String> _callGeminiWithFile({
    required String    systemPrompt,
    required String    userMessage,
    required Uint8List fileBytes,
    required String    mimeType,
    int attempt = 0,
  }) async {
    final b64 = base64Encode(fileBytes);
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data':       b64,
                },
              },
              {'text': '$systemPrompt\n\n$userMessage'},
            ],
          },
        ],
      }),
    );
    // 429 = rate limited — wait 3 s and retry once
    if (response.statusCode == 429 && attempt == 0) {
      await Future.delayed(const Duration(seconds: 3));
      return _callGeminiWithFile(
        systemPrompt: systemPrompt,
        userMessage:  userMessage,
        fileBytes:    fileBytes,
        mimeType:     mimeType,
        attempt:      1,
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Gemini file API error: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ── JSON helpers ─────────────────────────────────────────────────────────────

  static Map<String, dynamic>? parseJsonResponse(String text) {
    String clean = text.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fence.firstMatch(clean);
    if (match != null) clean = match.group(1)!.trim();
    try { return jsonDecode(clean) as Map<String, dynamic>; } catch (_) { return null; }
  }

  static List<Map<String, dynamic>>? parseJsonArray(String text) {
    String clean = text.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = fence.firstMatch(clean);
    if (match != null) clean = match.group(1)!.trim();
    try {
      return (jsonDecode(clean) as List).cast<Map<String, dynamic>>();
    } catch (_) { return null; }
  }
}
