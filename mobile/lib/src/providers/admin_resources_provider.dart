import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/resource_model.dart';
import '../services/api_service.dart';

class AdminResourcesState {
  final List<ResourceModel> resources;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;
  final String status; // 'active' | 'inactive' | 'all'

  const AdminResourcesState({
    this.resources = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
    this.status = 'active',
  });

  AdminResourcesState copyWith({
    List<ResourceModel>? resources,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
    String? status,
  }) {
    return AdminResourcesState(
      resources: resources ?? this.resources,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      status: status ?? this.status,
    );
  }
}

class AdminResourcesNotifier extends StateNotifier<AdminResourcesState> {
  final ApiService _api;
  final _log = Logger();
  AdminResourcesNotifier(this._api) : super(const AdminResourcesState());

  Future<void> load({String status = 'active', bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (refresh || status != state.status) {
      state = AdminResourcesState(isLoading: true, status: status);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final qp = {
        'page': refresh || status != state.status ? 1 : state.currentPage,
        'limit': 20,
        'status': status,
      };
      final resp = await _api.get('/resources/admin', queryParameters: qp);
      if (resp.statusCode == 200) {
        final data = resp.data;
        final list = (data['resources'] as List)
            .map((e) => ResourceModel.fromJson(_normalizeResourceJson(e)))
            .toList();
        final pagination = data['pagination'];
        final hasMore = pagination['page'] < pagination['pages'];
        if (refresh || status != state.status) {
          state = AdminResourcesState(
              resources: list,
              isLoading: false,
              hasMore: hasMore,
              currentPage: pagination['page'],
              status: status);
        } else {
          state = state.copyWith(
            resources: [...state.resources, ...list],
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
          );
        }
      } else {
        state = state.copyWith(isLoading: false, error: 'Error cargando');
      }
    } catch (e) {
      _log.e('AdminResources load error: $e');
      state = state.copyWith(isLoading: false, error: 'Error de conexión');
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
    await load(status: state.status);
  }
}

final adminResourcesProvider =
    StateNotifierProvider<AdminResourcesNotifier, AdminResourcesState>((ref) {
  final api = ref.read(apiServiceProvider);
  return AdminResourcesNotifier(api);
});

Map<String, dynamic> _normalizeResourceJson(dynamic json) {
  final map = Map<String, dynamic>.from(json as Map);
  final rawType = (map['type'] ?? '').toString().toUpperCase();
  if (rawType == 'STORAGESPACE') map['type'] = 'STORAGE_SPACE';
  if (rawType == 'LASERMACHINE') map['type'] = 'LASER_MACHINE';
  // Ensure ids are strings where needed
  for (final k in ['id', 'ownerId']) {
    final v = map[k];
    if (v is int) map[k] = v.toString();
  }
  // Images normalization
  final imgs = map['images'];
  if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
    map['images'] =
        imgs.map((e) => (e as Map)['url']).whereType<String>().toList();
  }
  return map;
}
