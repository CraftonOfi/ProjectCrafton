import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart';

class AdminBookingsState {
  final List<BookingModel> bookings;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;
  final BookingStatus? filterStatus;

  const AdminBookingsState({
    this.bookings = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
    this.filterStatus,
  });

  AdminBookingsState copyWith({
    List<BookingModel>? bookings,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
    BookingStatus? filterStatus,
  }) {
    return AdminBookingsState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class AdminBookingsNotifier extends StateNotifier<AdminBookingsState> {
  final ApiService _apiService;
  final Logger _logger = Logger();

  AdminBookingsNotifier(this._apiService) : super(const AdminBookingsState());

  Map<String, dynamic> _sanitize(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    // Coerce IDs to strings
    for (final k in ['id', 'userId', 'resourceId']) {
      final v = map[k];
      if (v is int) map[k] = v.toString();
    }
    // Resource images -> List<String>
    final res = map['resource'];
    if (res is Map<String, dynamic>) {
      final imgs = res['images'];
      if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
        res['images'] =
            imgs.map((e) => (e as Map)['url']).whereType<String>().toList();
      }
      for (final k in ['id', 'ownerId']) {
        final v = res[k];
        if (v is int) res[k] = v.toString();
      }
    }
    return map;
  }

  Future<void> loadAll({BookingStatus? status, bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (refresh) {
      state = AdminBookingsState(isLoading: true, filterStatus: status);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final qp = <String, dynamic>{
        'page': refresh ? 1 : state.currentPage,
        'limit': 20,
      };
      if (status != null) qp['status'] = _mapStatusToApi(status);

      final resp =
          await _apiService.get('/bookings/admin/all', queryParameters: qp);
      if (resp.statusCode == 200) {
        final data = resp.data;
        final list = (data['bookings'] as List)
            .map((e) => BookingModel.fromJson(_sanitize(e)))
            .toList();
        final pagination = data['pagination'];
        final hasMore = pagination['page'] < pagination['pages'];

        if (refresh) {
          state = AdminBookingsState(
            bookings: list,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
            filterStatus: status,
          );
        } else {
          state = state.copyWith(
            bookings: [...state.bookings, ...list],
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
          );
        }
      } else {
        state = state.copyWith(isLoading: false, error: 'Error cargando');
      }
    } on ApiException catch (e) {
      _logger.e('AdminBookings loadAll error: ${e.message}');
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      _logger.e('AdminBookings loadAll error: $e');
      state = state.copyWith(isLoading: false, error: 'Error de conexión');
    }
  }

  Future<bool> updateStatus(String bookingId, BookingStatus status) async {
    try {
      final resp = await _apiService.put('/bookings/$bookingId/status',
          data: {'status': _mapStatusToApi(status)});
      if (resp.statusCode == 200) {
        final map = _sanitize(resp.data['booking']);
        final updated = BookingModel.fromJson(map);
        final updatedList =
            state.bookings.map((b) => b.id == bookingId ? updated : b).toList();
        state = state.copyWith(bookings: updatedList);
        return true;
      }
    } on ApiException catch (e) {
      _logger.e('AdminBookings updateStatus error: ${e.message}');
    }
    return false;
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
    await loadAll(status: state.filterStatus);
  }
}

String _mapStatusToApi(BookingStatus s) {
  switch (s) {
    case BookingStatus.pending:
      return 'PENDING';
    case BookingStatus.confirmed:
      return 'CONFIRMED';
    case BookingStatus.inProgress:
      return 'IN_PROGRESS';
    case BookingStatus.completed:
      return 'COMPLETED';
    case BookingStatus.cancelled:
      return 'CANCELLED';
    case BookingStatus.refunded:
      return 'REFUNDED';
  }
}

final adminBookingsProvider =
    StateNotifierProvider<AdminBookingsNotifier, AdminBookingsState>((ref) {
  final api = ref.read(apiServiceProvider);
  return AdminBookingsNotifier(api);
});
