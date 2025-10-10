import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';

class ThreadSummary {
  final int id; // counterpart user id
  final String name;
  final String email;
  final String role;
  final DateTime? lastMessageAt;
  final int unread;
  ThreadSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.lastMessageAt,
    required this.unread,
  });
  factory ThreadSummary.fromJson(Map<String, dynamic> j) => ThreadSummary(
        id: (j['id'] as num).toInt(),
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? '',
        lastMessageAt: j['lastMessageAt'] != null
            ? DateTime.tryParse(j['lastMessageAt'].toString())
            : null,
        unread: (j['unread'] ?? 0) is num ? (j['unread'] as num).toInt() : 0,
      );
}

class ChatMessage {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String body;
  final bool read;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;
  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.body,
    required this.read,
    required this.createdAt,
    this.attachments = const [],
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        fromUserId: (j['fromUserId'] as num).toInt(),
        toUserId: (j['toUserId'] as num).toInt(),
        body: j['body'] ?? '',
        read: j['read'] == true,
        createdAt:
            DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now(),
        attachments: ((j['attachments'] as List?) ?? [])
            .map((e) =>
                MessageAttachment.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class MessageAttachment {
  final String url;
  final String? type;
  MessageAttachment({required this.url, this.type});
  factory MessageAttachment.fromJson(Map<String, dynamic> j) =>
      MessageAttachment(url: j['url'] ?? '', type: j['type'] as String?);
}

class ThreadsState {
  final bool loading;
  final List<ThreadSummary> threads;
  final String? error;
  ThreadsState({this.loading = false, this.threads = const [], this.error});
  ThreadsState copyWith(
          {bool? loading,
          List<ThreadSummary>? threads,
          String? error,
          bool clearError = false}) =>
      ThreadsState(
        loading: loading ?? this.loading,
        threads: threads ?? this.threads,
        error: clearError ? null : (error ?? this.error),
      );
}

class MessagesState {
  final bool loading;
  final List<ChatMessage> messages;
  final int page;
  final int pages;
  final String? error;
  final bool typing;
  MessagesState(
      {this.loading = false,
      this.messages = const [],
      this.page = 1,
      this.pages = 1,
      this.error,
      this.typing = false});
  MessagesState copyWith(
          {bool? loading,
          List<ChatMessage>? messages,
          int? page,
          int? pages,
          String? error,
          bool clearError = false,
          bool? typing}) =>
      MessagesState(
        loading: loading ?? this.loading,
        messages: messages ?? this.messages,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        error: clearError ? null : (error ?? this.error),
        typing: typing ?? this.typing,
      );
}

class ThreadsNotifier extends StateNotifier<ThreadsState> {
  final ChatService _chat;
  ThreadsNotifier(this._chat) : super(ThreadsState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _chat.fetchThreads();
      final list = (data['threads'] as List? ?? [])
          .map((e) => ThreadSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(loading: false, threads: list);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatService _chat;
  final int counterpartId;
  MessagesNotifier(this._chat, this.counterpartId) : super(MessagesState());

  Future<void> load({int page = 1}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _chat.fetchMessages(userId: counterpartId, page: page);
      final items = (data['messages'] as List? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final pagination = (data['pagination'] as Map?) ?? {};
      state = state.copyWith(
        loading: false,
        messages: page == 1 ? items : [...state.messages, ...items],
        page: pagination['page'] is int ? pagination['page'] as int : page,
        pages: pagination['pages'] is int
            ? pagination['pages'] as int
            : state.pages,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> send(String message) async {
    try {
      final resp =
          await _chat.sendMessage(toUserId: counterpartId, message: message);
      final created = ChatMessage.fromJson(
          (resp['message'] as Map).cast<String, dynamic>());
      state = state.copyWith(messages: [...state.messages, created]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setTyping(bool value) {
    state = state.copyWith(typing: value);
  }
}

final threadsProvider =
    StateNotifierProvider<ThreadsNotifier, ThreadsState>((ref) {
  final chat = ref.read(chatServiceProvider);
  return ThreadsNotifier(chat);
});

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, MessagesState, int>(
        (ref, counterpartId) {
  final chat = ref.read(chatServiceProvider);
  return MessagesNotifier(chat, counterpartId);
});
