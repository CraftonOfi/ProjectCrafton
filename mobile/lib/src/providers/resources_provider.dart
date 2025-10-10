import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/resource_model.dart';
import '../services/api_service.dart';
import '../services/api_service.dart' show apiServiceProvider, ApiException;

// Estado para la lista de recursos
class ResourcesState {
  final List<ResourceModel> resources;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;

  const ResourcesState({
    this.resources = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
  });

  ResourcesState copyWith({
    List<ResourceModel>? resources,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return ResourcesState(
      resources: resources ?? this.resources,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  String toString() {
    return 'ResourcesState(resources: ${resources.length}, isLoading: $isLoading, hasMore: $hasMore, error: $error)';
  }
}

// Notifier para manejar recursos
class ResourcesNotifier extends StateNotifier<ResourcesState> {
  final ApiService _apiService;
  final Logger _logger = Logger();
  // Memoización simple por clave de filtros
  final Map<String, List<ResourceModel>> _cache = {};

  ResourcesNotifier(this._apiService) : super(const ResourcesState());

  // Cargar recursos con filtros opcionales
  Future<void> loadResources({
    ResourceType? type,
    List<ResourceType>? types,
    String? location,
    List<String>? locations,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? sort, // price_asc | price_desc | created_asc | created_desc
    bool refresh = false,
  }) async {
    if (state.isLoading && !refresh) return;

    // Si es refresh, resetear el estado
    if (refresh) {
      state = const ResourcesState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final queryParams = <String, dynamic>{
        'page': refresh ? 1 : state.currentPage,
        'limit': 20,
      };

      final hasMultiTypes = types != null && types.isNotEmpty;
      final hasSingleType = type != null;
      if (hasMultiTypes) {
        queryParams['types'] = types.map(_mapTypeToApi).join(',');
      } else if (hasSingleType) {
        queryParams['type'] = _mapTypeToApi(type);
      }

      final hasMultiLocations = locations != null && locations.isNotEmpty;
      final hasSingleLocation = location != null && location.isNotEmpty;
      if (hasMultiLocations) {
        queryParams['locations'] = locations.join(',');
      } else if (hasSingleLocation) {
        queryParams['location'] = location;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (minPrice != null) {
        queryParams['minPrice'] = minPrice;
      }
      if (maxPrice != null) {
        queryParams['maxPrice'] = maxPrice;
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      // Cache key a partir de filtros relevantes y página
      final cacheKey = [
        'p=${queryParams['page']}',
        't=${type?.name}',
        'ts=${types?.map((e) => e.name).join(',')}',
        'loc=${location ?? ''}',
        'locs=${locations?.join(',') ?? ''}',
        'q=${search ?? ''}',
        'min=${minPrice ?? ''}',
        'max=${maxPrice ?? ''}',
        'sort=${sort ?? ''}',
      ].join('|');

      if (refresh && _cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey]!;
        state = ResourcesState(
          resources: cached,
          isLoading: false,
          hasMore: false,
          currentPage: 1,
        );
        return;
      }

      final response =
          await _apiService.get('/resources', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final data = response.data;
        List<ResourceModel> resourcesList = (data['resources'] as List)
            .map((json) => ResourceModel.fromJson(
                _normalizeResourceJson(json as Map<String, dynamic>)))
            .toList();

        // Post-filtrado case-insensitive temporal para SQLite (cuando backend no soporta mode: 'insensitive').
        if (search != null && search.trim().isNotEmpty) {
          final term = search.trim().toLowerCase();
          resourcesList = resourcesList.where((r) {
            final name = r.name.toLowerCase();
            final desc = r.description.toLowerCase();
            final loc = (r.location ?? '').toLowerCase();
            return name.contains(term) ||
                desc.contains(term) ||
                loc.contains(term);
          }).toList();
        }

        final pagination = data['pagination'];
        final hasMore = pagination['page'] < pagination['pages'];

        if (refresh) {
          // Si es refresh, reemplazar toda la lista
          state = ResourcesState(
            resources: resourcesList,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
          );
          _cache[cacheKey] = resourcesList;
        } else {
          // Si no es refresh, agregar a la lista existente
          final updatedResources = [...state.resources, ...resourcesList];
          state = state.copyWith(
            resources: updatedResources,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
          );
        }

        _logger.i(
            'Recursos cargados: ${resourcesList.length}, Total: ${state.resources.length}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Error cargando recursos',
        );
      }
    } on ApiException catch (e) {
      _logger.e('Error API cargando recursos: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e.message),
      );
    } catch (e) {
      _logger.e('Error cargando recursos: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión',
      );
    }
  }

  // Cargar más recursos (paginación)
  Future<void> loadMoreResources({
    ResourceType? type,
    List<ResourceType>? types,
    String? location,
    List<String>? locations,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? sort,
  }) async {
    if (!state.hasMore || state.isLoading) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(currentPage: nextPage);

    await loadResources(
      type: type,
      types: types,
      location: location,
      locations: locations,
      search: search,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sort: sort,
    );
  }

  // Obtener un recurso específico
  Future<ResourceModel?> getResource(String resourceId) async {
    try {
      _logger.d('Obteniendo recurso: $resourceId');

      final response = await _apiService.get('/resources/$resourceId');

      if (response.statusCode == 200) {
        final resourceData = response.data['resource'];
        final resource = ResourceModel.fromJson(resourceData);

        _logger.i('Recurso obtenido: ${resource.name}');
        return resource;
      }
    } on ApiException catch (e) {
      _logger.e('Error API obteniendo recurso: ${e.message}');
    } catch (e) {
      _logger.e('Error obteniendo recurso: $e');
    }
    return null;
  }

  // Crear nuevo recurso (solo admin)
  Future<bool> createResource({
    required String name,
    required String description,
    required ResourceType type,
    required double pricePerHour,
    String? location,
    String? capacity,
    Map<String, dynamic>? specifications,
    List<String>? images,
  }) async {
    try {
      _logger.d('Creando recurso: $name');

      final response = await _apiService.post('/resources', data: {
        'name': name,
        'description': description,
        'type': _mapTypeToApi(type),
        'pricePerHour': pricePerHour,
        if (location != null) 'location': location,
        if (capacity != null) 'capacity': capacity,
        if (specifications != null) 'specifications': specifications,
        'images': images ?? [],
      });

      if (response.statusCode == 201) {
        final resourceData = response.data['resource'];
        final newResource = ResourceModel.fromJson(resourceData);

        // Agregar el nuevo recurso al inicio de la lista
        state = state.copyWith(
          resources: [newResource, ...state.resources],
        );

        _logger.i('Recurso creado exitosamente: ${newResource.name}');
        return true;
      }
    } on ApiException catch (e) {
      _logger.e('Error API creando recurso: ${e.message}');
    } catch (e) {
      _logger.e('Error creando recurso: $e');
    }
    return false;
  }

  // Actualizar recurso (solo admin)
  Future<bool> updateResource(
    String resourceId, {
    String? name,
    String? description,
    double? pricePerHour,
    String? location,
    String? capacity,
    Map<String, dynamic>? specifications,
    List<String>? images,
    bool? isActive,
  }) async {
    try {
      _logger.d('Actualizando recurso: $resourceId');

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (pricePerHour != null) data['pricePerHour'] = pricePerHour;
      if (location != null) data['location'] = location;
      if (capacity != null) data['capacity'] = capacity;
      if (specifications != null) data['specifications'] = specifications;
      if (images != null) data['images'] = images;
      if (isActive != null) data['isActive'] = isActive;

      final response =
          await _apiService.put('/resources/$resourceId', data: data);

      if (response.statusCode == 200) {
        final resourceData = response.data['resource'];
        final updatedResource = ResourceModel.fromJson(resourceData);

        // Actualizar en la lista local
        final updatedResources = state.resources.map((resource) {
          return resource.id == resourceId ? updatedResource : resource;
        }).toList();

        state = state.copyWith(resources: updatedResources);

        _logger.i('Recurso actualizado exitosamente');
        return true;
      }
    } on ApiException catch (e) {
      _logger.e('Error API actualizando recurso: ${e.message}');
    } catch (e) {
      _logger.e('Error actualizando recurso: $e');
    }
    return false;
  }

  // Eliminar recurso (solo admin)
  Future<bool> deleteResource(String resourceId) async {
    try {
      _logger.d('Eliminando recurso: $resourceId');

      final response = await _apiService.delete('/resources/$resourceId');

      if (response.statusCode == 200) {
        // Remover de la lista local
        final updatedResources = state.resources
            .where((resource) => resource.id != resourceId)
            .toList();

        state = state.copyWith(resources: updatedResources);

        _logger.i('Recurso eliminado exitosamente');
        return true;
      }
    } on ApiException catch (e) {
      _logger.e('Error API eliminando recurso: ${e.message}');
    } catch (e) {
      _logger.e('Error eliminando recurso: $e');
    }
    return false;
  }

  // Buscar recursos
  @Deprecated('Usar loadResources(search: ...) en su lugar')
  Future<void> searchResources(String query) async {
    await loadResources(refresh: true, search: query);
  }

  // Limpiar errores
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Resetear estado
  void reset() {
    state = const ResourcesState();
  }
}

String _friendlyError(String raw) {
  if (raw.contains('500')) return 'Error interno del servidor';
  if (raw.toLowerCase().contains('socket')) {
    return 'No se pudo conectar con el servidor';
  }
  return raw;
}

// ================= Helpers de normalización de tipos =================

String _mapTypeToApi(ResourceType type) {
  switch (type) {
    case ResourceType.storageSpace:
      return 'STORAGE_SPACE';
    case ResourceType.laserMachine:
      return 'LASER_MACHINE';
  }
}

Map<String, dynamic> _normalizeResourceJson(Map<String, dynamic> json) {
  // Corrige tipos mal guardados (STORAGESPACE / LASERMACHINE) a formato correcto
  final rawType = (json['type'] ?? '').toString().toUpperCase();
  if (rawType == 'STORAGESPACE') json['type'] = 'STORAGE_SPACE';
  if (rawType == 'LASERMACHINE') json['type'] = 'LASER_MACHINE';
  return json;
}

// Provider para el ResourcesNotifier
final resourcesProvider =
    StateNotifierProvider<ResourcesNotifier, ResourcesState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ResourcesNotifier(apiService);
});

// Provider para obtener un recurso específico
final resourceProvider =
    FutureProvider.family<ResourceModel?, String>((ref, resourceId) {
  final notifier = ref.read(resourcesProvider.notifier);
  return notifier.getResource(resourceId);
});

// Provider para filtrar recursos por tipo
final resourcesByTypeProvider =
    Provider.family<List<ResourceModel>, ResourceType?>((ref, type) {
  final resources = ref.watch(resourcesProvider).resources;

  if (type == null) return resources;

  return resources.where((resource) => resource.type == type).toList();
});

// Provider para estadísticas de recursos (admin)
final resourceStatsProvider = Provider<Map<String, int>>((ref) {
  final resources = ref.watch(resourcesProvider).resources;

  return {
    'total': resources.length,
    'storage':
        resources.where((r) => r.type == ResourceType.storageSpace).length,
    'laser': resources.where((r) => r.type == ResourceType.laserMachine).length,
    'active': resources.where((r) => r.isActive).length,
    'inactive': resources.where((r) => !r.isActive).length,
  };
});
