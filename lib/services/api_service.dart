import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/obligation_model.dart';
import '../models/user_model.dart';
import '../models/insights_model.dart';
import '../models/morning_brief_model.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static String get _baseUrl =>
      dotenv.env['EXPO_PUBLIC_API_URL'] ?? AppConstants.defaultApiUrl;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl:        _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers:        {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.keyAuthToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email, 'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? location,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name, 'email': email, 'password': password,
      if (location != null) 'location': location,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Obligations ────────────────────────────────────────────────────────────
  Future<List<ObligationModel>> fetchObligations() async {
    final res = await _dio.get('/obligations');
    final data = res.data as Map<String, dynamic>;
    final list = data['data'] as List;
    return list.map((e) => ObligationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ObligationModel> createObligation(Map<String, dynamic> payload) async {
    final res = await _dio.post('/obligations', data: payload);
    return ObligationModel.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  Future<void> updateObligation(String id, Map<String, dynamic> payload) async {
    await _dio.put('/obligations/$id', data: payload);
  }

  Future<void> resolveObligation(String id) async {
    await _dio.patch('/obligations/$id/resolve');
  }

  // ── Brief ──────────────────────────────────────────────────────────────────
  Future<MorningBriefModel> fetchBrief(String type) async {
    final res = await _dio.get('/brief', queryParameters: {'type': type});
    return MorningBriefModel.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  // ── Insights ───────────────────────────────────────────────────────────────
  Future<InsightsModel> fetchInsights() async {
    final res = await _dio.get('/insights');
    return InsightsModel.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  // ── User ───────────────────────────────────────────────────────────────────
  Future<UserModel> fetchProfile() async {
    final res = await _dio.get('/user/profile');
    return UserModel.fromJson((res.data as Map<String, dynamic>)['data']);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> payload) async {
    final res = await _dio.patch('/user/profile', data: payload);
    return UserModel.fromJson((res.data as Map<String, dynamic>)['data']);
  }
}
