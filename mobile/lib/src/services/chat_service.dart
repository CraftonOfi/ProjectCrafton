import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

final chatServiceProvider = Provider<ChatService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ChatService(api);
});
