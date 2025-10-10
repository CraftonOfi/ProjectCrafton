import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class AdminSummaryState {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;
  final int rangeDays; // UI: días seleccionados para el rango dinámico
  final Map<String, dynamic>? rangeData; // respuesta de /admin/range
  const AdminSummaryState({
    this.loading = false,
    this.error,
    this.data,
    this.rangeDays = 30,
    this.rangeData,
  });
  AdminSummaryState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? data,
    int? rangeDays,
    Map<String, dynamic>? rangeData,
    bool clearError = false,
  }) =>
      AdminSummaryState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        data: data ?? this.data,
        rangeDays: rangeDays ?? this.rangeDays,
        rangeData: rangeData ?? this.rangeData,
      );
}

class AdminReportsNotifier extends StateNotifier<AdminSummaryState> {
  final ApiService _api;
  final Map<int, Map<String, dynamic>> _rangeCache = {};
  AdminReportsNotifier(this._api) : super(const AdminSummaryState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final resp = await _api.get('/reports/admin/summary');

      // Validar estado HTTP y forma del payload
      final status = resp.statusCode ?? 500;
      final data = resp.data;

      if (status >= 400) {
        final msg = (data is Map)
            ? (data['error'] ?? data['message'] ?? 'Error $status').toString()
            : 'Error $status';
        state = state.copyWith(loading: false, error: msg);
        return;
      }

      if (data is! Map) {
        state = state.copyWith(
            loading: false, error: 'Respuesta inválida del servidor');
        return;
      }

      state = state.copyWith(
        loading: false,
        data: data.cast<String, dynamic>(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadRange(int days) async {
    state = state.copyWith(loading: true, rangeDays: days, clearError: true);
    // Cache por rango
    final cached = _rangeCache[days];
    if (cached != null) {
      state = state.copyWith(loading: false, rangeData: cached);
      return;
    }
    try {
      final resp = await _api.get('/reports/admin/range', queryParameters: {
        'days': days,
      });
      final status = resp.statusCode ?? 500;
      final data = resp.data;
      if (status >= 400 || data is! Map) {
        final msg = (data is Map)
            ? (data['error'] ?? data['message'] ?? 'Error $status').toString()
            : 'Error $status';
        state = state.copyWith(loading: false, error: msg);
        return;
      }
      final mapped = data.cast<String, dynamic>();
      _rangeCache[days] = mapped;
      state = state.copyWith(loading: false, rangeData: mapped);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final adminReportsProvider =
    StateNotifierProvider<AdminReportsNotifier, AdminSummaryState>((ref) {
  final api = ref.read(apiServiceProvider);
  return AdminReportsNotifier(api);
});
