import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_dio/sentry_dio.dart';

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
          // Permite override en build/run: --dart-define=API_BASE_URL=http://localhost:3002/api
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            // Use 127.0.0.1 on Web to avoid potential IPv6 localhost issues
            defaultValue: kIsWeb
                ? 'http://127.0.0.1:3001/api'
                : 'http://10.0.2.2:3001/api',
          ),
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 3),
          // Permitimos que Dio no lance excepción automáticamente para capturar cuerpo de error
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 500,
        )) {
    dio.addSentry();
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));

    // Interceptor 401 -> marcar en extra para gestionar logout en capa superior
    dio.interceptors.add(InterceptorsWrapper(onError: (e, handler) async {
      if (e.response?.statusCode == 401) {
        e.requestOptions.extra['__auth_401__'] = true;
      }
      return handler.next(e);
    }));

    // Idempotency + retries con backoff + fallback local-dev.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final method = options.method.toUpperCase();
        final isMutating = method == 'POST' ||
            method == 'PUT' ||
            method == 'PATCH' ||
            method == 'DELETE';
        if (isMutating && options.headers['Idempotency-Key'] == null) {
          options.headers['Idempotency-Key'] = _generateIdempotencyKey(options);
        }
        options.extra['retryCount'] ??= 0;
        return handler.next(options);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        final method = req.method.toUpperCase();
        final isIdempotent =
            method == 'GET' || req.headers.containsKey('Idempotency-Key');
        final status = e.response?.statusCode;
        final isNetworkError =
            e.response == null && e.type != DioExceptionType.badResponse;
        final isRetryableStatus =
            status != null && status >= 500 && status < 600;
        final currentRetries = (req.extra['retryCount'] as int? ?? 0);
        const maxRetries = 2;

        // 1) Retries con backoff para solicitudes idempotentes
        if (isIdempotent &&
            currentRetries < maxRetries &&
            (isNetworkError || isRetryableStatus)) {
          try {
            final delayMs = 250 * (1 << currentRetries); // 250ms, 500ms
            await Future.delayed(Duration(milliseconds: delayMs));
            final response = await dio.request(
              req.path,
              data: req.data,
              queryParameters: req.queryParameters,
              options: Options(
                method: req.method,
                headers: req.headers,
                responseType: req.responseType,
                contentType: req.contentType,
                followRedirects: req.followRedirects,
                receiveDataWhenStatusError: req.receiveDataWhenStatusError,
                extra: {...req.extra, 'retryCount': currentRetries + 1},
              ),
              cancelToken: req.cancelToken,
              onReceiveProgress: req.onReceiveProgress,
              onSendProgress: req.onSendProgress,
            );
            return handler.resolve(response);
          } catch (_) {
            // continue to fallback
          }
        }

        // 2) Fallback local-dev: alterna host/puerto si es error de red y aún no probamos fallback
        final alreadyRetriedFallback = req.extra['retriedWithFallback'] == true;
        if (isNetworkError && !alreadyRetriedFallback) {
          try {
            final current = dio.options.baseUrl;
            final uri = Uri.tryParse(current);
            if (uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https')) {
              final hosts = <String>{
                uri.host,
                '127.0.0.1',
                'localhost',
                '10.0.2.2'
              };
              final ports = <int>{
                uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port,
                3001,
                3002,
              };
              final candidates = <Uri>[];
              for (final h in hosts) {
                for (final p in ports) {
                  final candidate = uri.replace(host: h, port: p);
                  if (candidate.toString() != current &&
                      !candidates.contains(candidate)) {
                    candidates.add(candidate);
                  }
                }
              }

              for (final cand in candidates) {
                try {
                  dio.options.baseUrl = cand.toString();
                  final response = await dio.request(
                    req.path,
                    data: req.data,
                    queryParameters: req.queryParameters,
                    options: Options(
                      method: req.method,
                      headers: req.headers,
                      contentType: req.contentType,
                      responseType: req.responseType,
                      followRedirects: req.followRedirects,
                      receiveDataWhenStatusError:
                          req.receiveDataWhenStatusError,
                      extra: {...req.extra, 'retriedWithFallback': true},
                    ),
                    cancelToken: req.cancelToken,
                    onReceiveProgress: req.onReceiveProgress,
                    onSendProgress: req.onSendProgress,
                  );
                  return handler.resolve(response);
                } catch (_) {
                  // probar siguiente candidato
                }
              }
            }
          } catch (_) {
            // ignora y propaga error original
          }
        }

        return handler.next(e);
      },
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

  Future<Map<String, dynamic>> uploadAvatarBytes(List<int> bytes,
      {String filename = 'avatar.jpg'}) async {
    try {
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await dio.post('/users/avatar',
          data: formData, options: Options(contentType: 'multipart/form-data'));
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
  String _generateIdempotencyKey(RequestOptions options) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Object().hashCode ^ options.path.hashCode ^ ts;
    return 'idem-$ts-$rnd';
  }

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
