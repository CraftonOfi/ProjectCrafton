import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'auth_provider.dart';
import '../services/api_service.dart';

class UserStatsState {
  final bool isLoading;
  final String? error;
  final int totalBookings;
  final int upcomingBookings;
  final int completedBookings;

  const UserStatsState({
    this.isLoading = false,
    this.error,
    this.totalBookings = 0,
    this.upcomingBookings = 0,
    this.completedBookings = 0,
  });

  UserStatsState copyWith({
    bool? isLoading,
    String? error,
    int? totalBookings,
    int? upcomingBookings,
    int? completedBookings,
  }) =>
      UserStatsState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        totalBookings: totalBookings ?? this.totalBookings,
        upcomingBookings: upcomingBookings ?? this.upcomingBookings,
        completedBookings: completedBookings ?? this.completedBookings,
      );
}

class UserStatsNotifier extends StateNotifier<UserStatsState> {
  final ApiService _apiService;
  final Logger _logger = Logger();
  final Ref _ref;

  UserStatsNotifier(this._apiService, this._ref)
      : super(const UserStatsState()) {
    _load();
  }

  Future<void> refresh() async => _load(force: true);

  Future<void> _load({bool force = false}) async {
    final isAuth = _ref.read(isAuthenticatedProvider);
    if (!isAuth) return;
    if (state.isLoading && !force) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.getProfile();
      if (result['success'] == true) {
        final user = result['user'];
        final bookings = (user['bookings'] as List?) ?? [];
        final now = DateTime.now();
        int upcoming = 0;
        int completed = 0;
        for (final b in bookings) {
          try {
            final endDate = DateTime.parse(b['endDate']);
            final status = (b['status'] ?? '').toString();
            if (endDate.isAfter(now) &&
                (status == 'CONFIRMED' ||
                    status == 'IN_PROGRESS' ||
                    status == 'PENDING')) {
              upcoming++;
            }
            if (status == 'COMPLETED') completed++;
          } catch (_) {}
        }
        state = state.copyWith(
          isLoading: false,
          totalBookings: bookings.length,
          upcomingBookings: upcoming,
          completedBookings: completed,
        );
      } else {
        state = state.copyWith(
            isLoading: false,
            error: result['message'] ?? 'Error cargando estadísticas');
      }
    } catch (e) {
      _logger.e('Error cargando estadísticas usuario: $e');
      state = state.copyWith(isLoading: false, error: 'Error de conexión');
    }
  }
}

final userStatsProvider =
    StateNotifierProvider<UserStatsNotifier, UserStatsState>((ref) {
  final api = ref.read(apiServiceProvider);
  return UserStatsNotifier(api, ref);
});
