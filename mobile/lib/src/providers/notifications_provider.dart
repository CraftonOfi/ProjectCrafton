import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime createdAt;
  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class NotificationsState {
  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int unreadCount;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? unreadCount,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiService _api;
  final _log = Logger();
  NotificationsNotifier(this._api) : super(const NotificationsState());

  Future<void> load({bool refresh = false, bool unreadOnly = false}) async {
    if (state.isLoading && !refresh) return;
    if (refresh) {
      state = const NotificationsState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final qp = {
        'page': refresh ? 1 : state.currentPage,
        'limit': 20,
        if (unreadOnly) 'unreadOnly': 'true',
      };
      final resp = await _api.get('/notifications', queryParameters: qp);
      if (resp.statusCode == 200) {
        final data = resp.data;
        final list = (data['notifications'] as List)
            .map((e) => NotificationItem.fromJson(e))
            .toList();
        final pagination = data['pagination'];
        final hasMore = pagination['page'] < pagination['pages'];
        if (refresh) {
          // Replace list and recompute unread count, keep sorted by most recent
          final sorted = [...list]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final unread = sorted.where((n) => !n.read).length;
          state = NotificationsState(
            items: sorted,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
            unreadCount: unread,
          );
        } else {
          // Merge-deduplicate by id, prefer newer entries from the server
          final map = {
            for (final n in state.items) n.id: n,
          };
          for (final n in list) {
            map[n.id] = n;
          }
          final merged = map.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final unread = merged.where((n) => !n.read).length;
          state = state.copyWith(
            items: merged,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
            unreadCount: unread,
          );
        }
      } else {
        state = state.copyWith(isLoading: false, error: 'Error cargando');
      }
    } catch (e) {
      _log.e('Notifications load error: $e');
      state = state.copyWith(isLoading: false, error: 'Error de conexión');
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
    await load();
  }

  Future<bool> markRead(String id) async {
    try {
      final resp = await _api.put('/notifications/$id/read');
      if (resp.statusCode == 200) {
        final items = state.items
            .map((n) => n.id == id
                ? NotificationItem(
                    id: n.id,
                    title: n.title,
                    message: n.message,
                    type: n.type,
                    read: true,
                    createdAt: n.createdAt,
                  )
                : n)
            .toList();
        final unread = items.where((n) => !n.read).length;
        state = state.copyWith(items: items, unreadCount: unread);
        return true;
      }
    } catch (e) {
      _log.e('markRead error: $e');
    }
    return false;
  }

  Future<bool> markAllRead() async {
    try {
      final resp = await _api.put('/notifications/read-all');
      if (resp.statusCode == 200) {
        final items = state.items
            .map((n) => NotificationItem(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  read: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        state = state.copyWith(items: items, unreadCount: 0);
        return true;
      }
    } catch (e) {
      _log.e('markAllRead error: $e');
    }
    return false;
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final api = ref.read(apiServiceProvider);
  return NotificationsNotifier(api);
});
