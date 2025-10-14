import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api;
  ChatService(this._api);

  Future<Map<String, dynamic>> fetchThreads() async {
    final resp = await _api.get('/chat/threads');
    if (resp.statusCode != 200 || resp.data is! Map) {
      throw ApiException('No se pudieron cargar los mensajes');
    }
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMessages(
      {required int userId, int page = 1, int limit = 30}) async {
    final resp = await _api.get('/chat/messages', queryParameters: {
      'userId': userId,
      'page': page,
      'limit': limit,
    });
    if (resp.statusCode != 200 || resp.data is! Map) {
      throw ApiException('No se pudieron cargar los mensajes');
    }
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(
      {required int toUserId,
      required String message,
      int? bookingId,
      List<Map<String, String>> attachments = const []}) async {
    final resp = await _api.post('/chat/messages', data: {
      'toUserId': toUserId,
      'message': message,
      if (bookingId != null) 'bookingId': bookingId,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<void> markRead(int messageId) async {
    await _api.put('/chat/messages/$messageId/read');
  }

  Future<Map<String, dynamic>> uploadAttachment(List<int> bytes,
      {required String filename, required String mimeType}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: filename, contentType: MediaType.parse(mimeType)),
    });
    final resp = await _api.dio.post('/chat/upload',
        data: formData, options: Options(contentType: 'multipart/form-data'));
    if (resp.statusCode != 200 || resp.data is! Map) {
      throw ApiException('Error subiendo archivo');
    }
    return resp.data as Map<String, dynamic>;
  }

  // Resuelve rutas relativas (p.ej. "/uploads/...") a URLs absolutas basadas en API_BASE_URL
  String resolveUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    final base = _api.dio.options.baseUrl; // p.ej. http://127.0.0.1:3001/api
    Uri? u;
    try {
      u = Uri.tryParse(base);
    } catch (_) {}
    if (u == null) return input;
    final origin =
        '${u.scheme}://${u.host}${(u.hasPort && u.port != 0) ? ':${u.port}' : ''}';
    if (input.startsWith('/')) return origin + input;
    return '$origin/$input';
  }
}

final chatServiceProvider = Provider<ChatService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ChatService(api);
});
