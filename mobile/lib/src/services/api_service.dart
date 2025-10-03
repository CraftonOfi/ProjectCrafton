import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        if (phone != null) 'phone': phone,
      });
      return _standardizeSuccess(response.data);
    } on DioException catch (e) {
      return _standardizeError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return _standardizeSuccess(response.data);
    } on DioException catch (e) {
      return _standardizeError(e);
    }
  }

  final Dio dio;

  // Stores the current authentication token for reference.
  String? _token;

  /// Returns the current authentication token, if any.
  String? get token => _token;

  ApiService()
      : dio = Dio(BaseOptions(
          baseUrl:
              kIsWeb ? 'http://localhost:3001/api' : 'http://10.0.2.2:3001/api',
          headers: {'Content-Type': 'application/json'},
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 3),
          // Permitimos que Dio no lance excepción automáticamente para capturar cuerpo de error
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 500,
        )) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  void clearToken() {
    _token = null;
    dio.options.headers.remove('Authorization');
  }

  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      final response =
          await dio.post('/auth/verify-token', data: {'token': token});
      return response.data;
    } on DioException catch (e) {
      return {'valid': false, 'message': e.message};
    }
  }

  Future<Map<String, dynamic>> updateProfile(
      {required String name, String? phone}) async {
    try {
      final response = await dio.put('/users/profile', data: {
        'name': name,
        if (phone != null) 'phone': phone,
      });
      return _standardizeSuccess(response.data);
    } on DioException catch (e) {
      return _standardizeError(e);
    }
  }

  Future<Map<String, dynamic>> changePassword(
      {required String currentPassword, required String newPassword}) async {
    try {
      final response = await dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return _standardizeSuccess(response.data);
    } on DioException catch (e) {
      return _standardizeError(e);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dio.get('/users/profile');
      return _standardizeSuccess(response.data);
    } on DioException catch (e) {
      return _standardizeError(e);
    }
  }

  // Métodos genéricos para recursos
  Future<Response> get(String endpoint,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      return await dio.get(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Error de conexión');
    }
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Error de conexión');
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Error de conexión');
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      return await dio.delete(endpoint);
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Error de conexión');
    }
  }
}

// Provider para ApiService (Riverpod)
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ===================== Helpers de normalización =====================
extension _ApiResponseHelpers on ApiService {
  Map<String, dynamic> _standardizeSuccess(Map<String, dynamic> data) {
    // Si ya trae success explícito lo respetamos
    if (data.containsKey('success')) return data;
    // Si viene un campo 'error' lo consideramos fallo
    if (data.containsKey('error')) {
      return {
        'success': false,
        'message': data['error'] ?? 'Error desconocido',
        ...data,
      };
    }
    // Éxito: añadimos success true
    return {
      'success': true,
      ...data,
    };
  }

  Map<String, dynamic> _standardizeError(DioException e) {
    final response = e.response;
    // Intentar extraer mensaje de varias claves comunes
    String? message;
    if (response?.data is Map) {
      final data = response!.data as Map;
      message = (data['error'] ?? data['message'] ?? data['detail']) as String?;
    }
    message ??= e.message;
    return {
      'success': false,
      'message': message ?? 'Error de conexión',
      'statusCode': response?.statusCode,
    };
  }
}
