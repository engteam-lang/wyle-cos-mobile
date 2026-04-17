/// Wyle AI Proxy Server
/// Runs on port 8081 alongside the Flutter web app.
/// Adds CORS headers so the browser can call Claude and Groq APIs.
///
/// Usage (in Codespace terminal):
///   dart run server/proxy.dart
///
/// Then forward port 8081 in VS Code → Ports tab.
/// Set PROXY_URL in your .env file to the forwarded HTTPS URL.

import 'dart:io';

const _proxyPort = 8081;

/// Maps proxy path → target API URL
const _routes = <String, String>{
  '/claude': 'https://api.anthropic.com/v1/messages',
  '/groq':   'https://api.groq.com/openai/v1/chat/completions',
};

void main() async {
  final server =
      await HttpServer.bind(InternetAddress.anyIPv4, _proxyPort);

  print('');
  print('  ✦  Wyle AI proxy  →  port $_proxyPort');
  print('     /claude  →  api.anthropic.com');
  print('     /groq    →  api.groq.com');
  print('');
  print('  Forward port $_proxyPort in VS Code (Ports tab),');
  print('  then add to .env:');
  print('  PROXY_URL=https://<codespace-name>-$_proxyPort.app.github.dev');
  print('');

  await for (final req in server) {
    _handle(req).catchError((e) {
      stderr.writeln('[proxy] error: $e');
    });
  }
}

Future<void> _handle(HttpRequest req) async {
  // Always set CORS headers
  req.response.headers
    ..add('Access-Control-Allow-Origin', '*')
    ..add('Access-Control-Allow-Methods', 'POST, OPTIONS')
    ..add('Access-Control-Allow-Headers',
        'Content-Type, x-api-key, anthropic-version, anthropic-beta, Authorization');

  // Handle preflight
  if (req.method == 'OPTIONS') {
    req.response.statusCode = HttpStatus.ok;
    await req.response.close();
    return;
  }

  final targetUrl = _routes[req.uri.path];
  if (targetUrl == null) {
    req.response.statusCode = HttpStatus.notFound;
    req.response.write('Unknown route: ${req.uri.path}');
    await req.response.close();
    return;
  }

  // Buffer the incoming body
  final bodyBytes =
      await req.fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));

  final client = HttpClient();
  try {
    final proxyReq = await client.postUrl(Uri.parse(targetUrl));

    // Forward headers — skip hop-by-hop AND browser-identity headers.
    // Stripping origin/referer prevents Anthropic from treating the request
    // as a browser CORS call (which would require anthropic-dangerous-direct-browser-access).
    const _skipReq = {
      'host', 'content-length', 'transfer-encoding', 'connection',
      'origin', 'referer',
    };
    req.headers.forEach((name, values) {
      if (!_skipReq.contains(name.toLowerCase())) {
        for (final v in values) proxyReq.headers.add(name, v);
      }
    });

    proxyReq.contentLength = bodyBytes.length;
    proxyReq.add(bodyBytes);

    final proxyRes = await proxyReq.close();

    req.response.statusCode = proxyRes.statusCode;

    // Forward response headers — skip hop-by-hop AND upstream CORS headers.
    // Upstream APIs (Groq) may return their own Access-Control-Allow-Origin: *
    // which would duplicate the one we already set above → browser rejects "*, *".
    const _skipRes = {
      'host', 'content-length', 'transfer-encoding', 'connection',
      'access-control-allow-origin',
      'access-control-allow-methods',
      'access-control-allow-headers',
      'access-control-expose-headers',
    };
    proxyRes.headers.forEach((name, values) {
      if (!_skipRes.contains(name.toLowerCase())) {
        for (final v in values) {
          try { req.response.headers.add(name, v); } catch (_) {}
        }
      }
    });

    await proxyRes.pipe(req.response);
  } finally {
    client.close();
  }
}
