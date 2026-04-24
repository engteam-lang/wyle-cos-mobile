import 'dart:typed_data';

// dart:io's Platform class is not available on Flutter Web.
// Use Flutter's defaultTargetPlatform instead (works everywhere).
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/action_item_model.dart';
import '../models/brain_dump_model.dart';
import '../models/conversation_model.dart';
import '../models/email_sync_model.dart';
import '../models/insights_summary_model.dart';

/// Single Dio client for all https://api.wyle.ai/v1 endpoints.
///
/// Token is read from SharedPreferences on every request via an interceptor.
/// Chat messages use a 120 s receive-timeout; audio uploads use 300 s.
class BuddyApiService {
  BuddyApiService._();
  static final BuddyApiService instance = BuddyApiService._();

  // ── Base URL ───────────────────────────────────────────────────────────────
  static String get _baseUrl =>
      dotenv.env['BUDDY_API_URL'] ?? AppConstants.buddyApiUrl;

  // ── Standard Dio (10 s connect / 30 s receive) ─────────────────────────────
  late final Dio _dio = Dio(BaseOptions(
    baseUrl:        _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers:        {'Content-Type': 'application/json'},
  ))..interceptors.add(_authInterceptor);

  // ── Long-timeout Dio for chat (120 s) ──────────────────────────────────────
  late final Dio _chatDio = Dio(BaseOptions(
    baseUrl:        _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120),
    headers:        {'Content-Type': 'application/json'},
  ))..interceptors.add(_authInterceptor);

  // ── Long-timeout Dio for file uploads (300 s) ─────────────────────────────
  late final Dio _uploadDio = Dio(BaseOptions(
    baseUrl:        _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 300),
  ))..interceptors.add(_authInterceptor);

  InterceptorsWrapper get _authInterceptor => InterceptorsWrapper(
    onRequest: (options, handler) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAuthToken);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Auth — OAuth
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns { "auth_url": "...", "state": "..." }
  ///
  /// Passes [mobileRedirectUri] so the backend redirects back to the app
  /// after OAuth instead of a web URL.
  /// Default:  com.wyle.buddy://oauth-callback
  Future<Map<String, dynamic>> startOAuth(
    String provider, {
    String mobileRedirectUri = 'com.wyle.buddy://oauth-callback',
  }) async {
    final res = await _dio.post('/auth/oauth/$provider/start', data: {
      'mobile_redirect_uri': mobileRedirectUri,
    });
    return res.data as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Profile & device
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /v1/users/me — linked accounts + email
  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    return res.data as Map<String, dynamic>;
  }

  /// GET /v1/users/me/ping — lightweight token health check
  Future<bool> ping() async {
    try {
      final res = await _dio.get('/users/me/ping');
      return (res.data as Map<String, dynamic>)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// POST /v1/users/me/device — register FCM token after login
  /// [platform] is 'android' or 'ios'
  Future<void> registerDevice({
    required String fcmToken,
    String? platform,
  }) async {
    final String plat = platform ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios');
    await _dio.post('/users/me/device', data: {
      'fcm_token': fcmToken,
      'platform':  plat,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Insights
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /v1/insights/summary?days=28
  Future<InsightsSummaryModel> getInsightsSummary({int days = 28}) async {
    final res = await _dio.get('/insights/summary',
        queryParameters: {'days': days});
    return InsightsSummaryModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Chat
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /v1/chat/conversations
  Future<List<ConversationModel>> getConversations() async {
    final res = await _chatDio.get('/chat/conversations');
    final list = res.data as List;
    return list
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /v1/chat/messages
  /// Pass [conversationId] = null to use latest/default thread.
  Future<ChatApiResponse> sendMessage({
    required String content,
    int? conversationId,
  }) async {
    final res = await _chatDio.post('/chat/messages', data: {
      'content':         content,
      'conversation_id': conversationId,
    });
    return ChatApiResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /v1/chat/conversations/{id}/messages
  Future<List<ConversationMessageModel>> getConversationMessages(
      int conversationId) async {
    final res =
        await _chatDio.get('/chat/conversations/$conversationId/messages');
    final list = res.data as List;
    return list
        .map((e) =>
            ConversationMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Brain dump (voice → tasks)
  // ══════════════════════════════════════════════════════════════════════════

  /// POST /v1/brain-dump/jobs — creates an empty job
  Future<BrainDumpJobModel> createBrainDumpJob() async {
    final res = await _dio.post('/brain-dump/jobs');
    return BrainDumpJobModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /v1/brain-dump/jobs/{id}/upload — upload audio bytes
  Future<BrainDumpJobModel> uploadBrainDumpAudio({
    required int    jobId,
    required Uint8List audioBytes,
    String          filename  = 'recording.webm',
    String          mimeType  = 'audio/webm',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final res = await _uploadDio.post(
      '/brain-dump/jobs/$jobId/upload',
      data: formData,
    );
    return BrainDumpJobModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /v1/brain-dump/jobs/{id} — poll until status != pending
  Future<BrainDumpJobModel> getBrainDumpJob(int jobId) async {
    final res = await _dio.get('/brain-dump/jobs/$jobId');
    return BrainDumpJobModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /v1/brain-dump/jobs/{id}/commit — save extracted items to inbox
  /// Pass [itemIndices] = null to commit all items.
  Future<BrainDumpCommitResult> commitBrainDumpJob({
    required int   jobId,
    List<int>?     itemIndices,
  }) async {
    final res = await _dio.post('/brain-dump/jobs/$jobId/commit', data: {
      'item_indices': itemIndices,
    });
    return BrainDumpCommitResult.fromJson(res.data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Action items (inbox / tasks / reminders)
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /v1/action-items — optional filters: source, kind, status
  Future<List<ActionItemModel>> getActionItems({
    String? source,
    String? kind,
    String? status,
  }) async {
    final res = await _dio.get('/action-items', queryParameters: {
      if (source != null) 'source': source,
      if (kind   != null) 'kind':   kind,
      if (status != null) 'status': status,
    });
    final list = res.data as List;
    return list
        .map((e) => ActionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /v1/action-items/{id}
  Future<ActionItemModel> getActionItem(int itemId) async {
    final res = await _dio.get('/action-items/$itemId');
    return ActionItemModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// PATCH /v1/action-items/{id} — change title, kind, remind_at, status, etc.
  Future<ActionItemModel> updateActionItem(
      int itemId, Map<String, dynamic> fields) async {
    final res = await _dio.patch('/action-items/$itemId', data: fields);
    return ActionItemModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Convenience: mark an action item done
  Future<ActionItemModel> markActionItemDone(int itemId) =>
      updateActionItem(itemId, {'status': 'done'});

  /// DELETE /v1/action-items/{id} — returns 204, no body
  Future<void> deleteActionItem(int itemId) async {
    await _dio.delete('/action-items/$itemId');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Email sync
  // ══════════════════════════════════════════════════════════════════════════

  /// POST /v1/integrations/email/sync-stub — demo sync (no real mailbox)
  /// [provider] = 'gmail' | 'microsoft'
  Future<EmailSyncStubResult> triggerEmailSyncStub(
      {String provider = 'gmail'}) async {
    final res = await _dio.post(
      '/integrations/email/sync-stub',
      queryParameters: {'provider': provider},
    );
    return EmailSyncStubResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /v1/integrations/email/sync — real sync (needs linked account)
  Future<EmailSyncJobModel> triggerEmailSync(
      {required String provider}) async {
    final res = await _dio.post('/integrations/email/sync', data: {
      'provider': provider,
    });
    return EmailSyncJobModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /v1/integrations/email/sync/jobs/{id} — poll until done / dead
  Future<EmailSyncJobModel> getEmailSyncJob(int jobId) async {
    final res = await _dio.get('/integrations/email/sync/jobs/$jobId');
    return EmailSyncJobModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Health
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> healthCheck() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
