import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'ai_service.dart';

class DocumentMetadata {
  final String type;
  final String? vendor;
  final double? amount;
  final String? date;
  final String summary;
  final String? suggestedObligationType;

  const DocumentMetadata({
    required this.type,
    this.vendor,
    this.amount,
    this.date,
    required this.summary,
    this.suggestedObligationType,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) => DocumentMetadata(
    type:                       json['type'] ?? 'document',
    vendor:                     json['vendor'],
    amount:                     (json['amount'] as num?)?.toDouble(),
    date:                       json['date'],
    summary:                    json['summary'] ?? '',
    suggestedObligationType:    json['suggestedObligationType'],
  );
}

class DriveFile {
  final String id;
  final String name;
  final String? mimeType;
  final String? webViewLink;
  final String? thumbnailLink;
  final String? createdTime;

  const DriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.webViewLink,
    this.thumbnailLink,
    this.createdTime,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) => DriveFile(
    id:            json['id'] ?? '',
    name:          json['name'] ?? '',
    mimeType:      json['mimeType'],
    webViewLink:   json['webViewLink'],
    thumbnailLink: json['thumbnailLink'],
    createdTime:   json['createdTime'],
  );
}

class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  static const String _folderName = 'Wyle Documents';

  Future<String?> _getToken() => GoogleAuthService.instance.getAccessToken();

  /// Upload a file to Google Drive "Wyle Documents" folder
  Future<DriveFile?> uploadFile({
    required File file,
    required String fileName,
    required String mimeType,
    String? email,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated with Google');

    // Ensure folder exists
    final folderId = await _ensureWyleFolder(token);

    final metadata = {
      'name':    fileName,
      'parents': [folderId],
    };

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink,createdTime'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['metadata'] = jsonEncode(metadata);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      await file.readAsBytes(),
      filename: fileName,
    ));

    final response = await request.send();
    final body     = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return DriveFile.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }
    throw Exception('Drive upload failed: ${response.statusCode}');
  }

  /// List files in the Wyle Documents folder
  Future<List<DriveFile>> listFiles() async {
    final token = await _getToken();
    if (token == null) return [];

    final folderId = await _ensureWyleFolder(token);
    final response = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        '?q=${Uri.encodeComponent("'$folderId' in parents and trashed=false")}'
        '&fields=files(id,name,mimeType,webViewLink,thumbnailLink,createdTime)'
        '&orderBy=createdTime desc',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) return [];

    final data  = jsonDecode(response.body) as Map<String, dynamic>;
    final files = data['files'] as List;
    return files.map((f) => DriveFile.fromJson(f as Map<String, dynamic>)).toList();
  }

  /// Delete a file from Drive
  Future<void> deleteFile(String fileId) async {
    final token = await _getToken();
    if (token == null) return;

    await http.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  /// Extract metadata from document using AI
  Future<DocumentMetadata> extractMetadata({
    required String fileName,
    String? textContent,
  }) async {
    try {
      final response = await AiService.instance.complete(
        systemPrompt: '''Extract metadata from document info and return JSON:
{
  "type": "invoice|passport|contract|insurance|visa|emirates_id|bill|receipt|medical|other",
  "vendor": "string or null",
  "amount": number or null,
  "date": "YYYY-MM-DD or null",
  "summary": "one-sentence summary",
  "suggestedObligationType": "visa|emirates_id|car_registration|insurance|school_fee|mortgage_emi|subscription|medical|document|bill|custom or null"
}
Return only JSON.''',
        userMessage: 'Filename: $fileName\n${textContent != null ? 'Content: ${textContent.substring(0, textContent.length.clamp(0, 1000))}' : ''}',
        maxTokens: 512,
      );

      final json = AiService.parseJsonResponse(response);
      if (json != null) return DocumentMetadata.fromJson(json);
    } catch (_) {}

    return DocumentMetadata(
      type:    _guessTypeFromName(fileName),
      summary: 'Uploaded document: $fileName',
    );
  }

  String _guessTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('invoice') || lower.contains('bill')) return 'invoice';
    if (lower.contains('passport')) return 'passport';
    if (lower.contains('insurance')) return 'insurance';
    if (lower.contains('visa')) return 'visa';
    if (lower.contains('contract')) return 'contract';
    return 'document';
  }

  Future<String> _ensureWyleFolder(String token) async {
    // Search for existing folder
    final searchRes = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        "?q=${Uri.encodeComponent("mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false")}"
        '&fields=files(id)',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (searchRes.statusCode == 200) {
      final data  = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final files = data['files'] as List;
      if (files.isNotEmpty) {
        return (files.first as Map<String, dynamic>)['id'] as String;
      }
    }

    // Create folder
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'name':     _folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      return (jsonDecode(createRes.body) as Map<String, dynamic>)['id'] as String;
    }

    throw Exception('Failed to create Drive folder');
  }
}
