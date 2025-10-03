import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../config/theme_config.dart';
import '../../models/resource_model.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/resource_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  ResourceType? _selectedType;
  String? _selectedLocation;
  // Advanced filters state
  final Set<ResourceType> _multiTypes = {};
  final Set<String> _multiLocations = {};
  RangeValues _priceRange = const RangeValues(0, 500); // default range
  double? _appliedMinPrice;
  double? _appliedMaxPrice;
  String? _sortKey; // price_asc | price_desc | created_asc | created_desc
  // Debounce timer
  Timer? _debounceTimer;
  // Sorting state (asc true means low->high)
  bool _sortPriceAsc = true; // to be used in sorting improvement

  @override
  void initState() {
    super.initState();
    // Cargar recursos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resourcesProvider.notifier).loadResources(refresh: true);
      // Snackbar error listener (improvement 3)
      ref.listen<ResourcesState>(resourcesProvider, (previous, next) {
        if (next.error != null &&
            next.error!.isNotEmpty &&
            previous?.error != next.error) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resourcesState = ref.watch(resourcesProvider);
    // Dynamic unique locations list (improvement 4)
    final dynamicLocations = {
      for (final r in resourcesState.resources)
        if (r.location != null && r.location!.trim().isNotEmpty)
          r.location!.trim()
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Recursos'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildSearchHeader(dynamicLocations),

          // Filtros rápidos
          _buildQuickFilters(),

          // Resultados
          _buildResultsHeader(resourcesState),

          // Lista de recursos
          Expanded(
            child: _buildResourcesList(resourcesState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdvancedFilters(dynamicLocations),
        icon: const Icon(Icons.filter_alt_outlined),
        label: const Text('Filtros'),
      ),
    );
  }

  Widget _buildSearchHeader(List<String> dynamicLocations) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.grey50,
        border: Border(
          bottom:
              BorderSide(color: isDark ? AppColors.grey700 : AppColors.grey200),
        ),
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          SearchTextField(
            controller: _searchController,
            hintText: 'Buscar espacios, máquinas...',
            onChanged: _handleSearch,
            onClear: () {
              _searchController.clear();
              _handleSearch('');
            },
          ),

          SizedBox(height: 12.h),

          // Filtros dropdown
          Row(
            children: [
              Expanded(
                child: _buildTypeFilter(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildLocationFilter(dynamicLocations),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border:
            Border.all(color: isDark ? AppColors.grey700 : AppColors.grey300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ResourceType?>(
          value: _selectedType,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
          iconEnabledColor:
              isDark ? AppColors.textSecondaryDark : AppColors.grey600,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
          hint: Text(
            'Tipo',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.grey500,
              fontSize: 14.sp,
            ),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'Todos los tipos',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            ...ResourceType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    type.displayName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildLocationFilter(List<String> dynamicLocations) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    // Sanitize selected location:
    // Flutter's DropdownButton asserts that the provided value exists exactly once
    // in the list of DropdownMenuItem values. Because our locations list is dynamic
    // (it depends on the current fetched resources), a previously selected location
    // might disappear after applying other filters (e.g., selecting a type or search
    // query that returns no resources from that location). That caused the assertion
    // failure you observed (e.g. with "Barcelona").
    // We defensively null out the selection if it's no longer present.
    final bool locationStillAvailable = _selectedLocation != null &&
        dynamicLocations.contains(_selectedLocation);
    final String? effectiveSelectedLocation =
        locationStillAvailable ? _selectedLocation : null;

    // If the stored state is stale (value vanished), schedule a state cleanup so
    // future refresh / pagination calls don't keep sending an invalid location.
    if (!locationStillAvailable && _selectedLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedLocation = null;
          });
        }
      });
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border:
            Border.all(color: isDark ? AppColors.grey700 : AppColors.grey300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: effectiveSelectedLocation,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
          iconEnabledColor:
              isDark ? AppColors.textSecondaryDark : AppColors.grey600,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
          hint: Text(
            'Ubicación',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.grey500,
              fontSize: 14.sp,
            ),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'Todas las ubicaciones',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            ...dynamicLocations.map((loc) => DropdownMenuItem(
                  value: loc,
                  child: Text(
                    loc,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedLocation = value;
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      height: 60.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _buildQuickFilterChip(
            'Espacios de Almacén',
            ResourceType.storageSpace,
            Icons.inventory_2_outlined,
            AppColors.primary,
          ),
          SizedBox(width: 8.w),
          _buildQuickFilterChip(
            'Máquinas Láser',
            ResourceType.laserMachine,
            Icons.precision_manufacturing_outlined,
            AppColors.secondary,
          ),
          SizedBox(width: 8.w),
          _buildQuickFilterChip(
            'Limpiar Filtros',
            null,
            Icons.clear_all,
            AppColors.grey600,
            isClearFilter: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(
    String label,
    ResourceType? type,
    IconData icon,
    Color color, {
    bool isClearFilter = false,
  }) {
    final isSelected = _selectedType == type && !isClearFilter;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: isSelected ? Colors.white : color,
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color),
      onSelected: (selected) {
        if (isClearFilter) {
          setState(() {
            _selectedType = null;
            _selectedLocation = null;
            _searchController.clear();
          });
          _applyFilters();
        } else {
          setState(() {
            _selectedType = selected ? type : null;
          });
          _applyFilters();
        }
      },
    );
  }

  Widget _buildResultsHeader(ResourcesState state) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    String resultsText;
    if (state.isLoading) {
      resultsText = 'Buscando...';
    } else if (state.resources.isEmpty) {
      resultsText = 'No se encontraron recursos';
    } else {
      resultsText =
          '${state.resources.length} recurso${state.resources.length != 1 ? 's' : ''} encontrado${state.resources.length != 1 ? 's' : ''}';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            resultsText,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          if (state.resources.isNotEmpty)
            InkWell(
              onTap: () {
                setState(() => _sortPriceAsc = !_sortPriceAsc);
                _applyFilters(sortChanged: true);
              },
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    Icon(
                      _sortPriceAsc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16.sp,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.grey500,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Precio',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResourcesList(ResourcesState state) {
    if (state.isLoading && state.resources.isEmpty) {
      return _buildLoadingState();
    }

    if (state.error != null && state.resources.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.resources.isEmpty) {
      return _buildEmptyState();
    }

    // Apply client-side price sorting (improvement 5)
    final sortedResources = [...state.resources];
    sortedResources.sort((a, b) {
      final priceA = a.pricePerHour;
      final priceB = b.pricePerHour;
      if (_sortPriceAsc) {
        return priceA.compareTo(priceB);
      } else {
        return priceB.compareTo(priceA);
      }
    });

    return RefreshIndicator(
      onRefresh: () => ref.read(resourcesProvider.notifier).loadResources(
            refresh: true,
            type: _selectedType,
            location: _selectedLocation,
          ),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: sortedResources.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.resources.length) {
            // Loading indicator para paginación
            if (state.isLoading) {
              return Padding(
                padding: EdgeInsets.all(24.w),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 8.h),
                      Text(
                        'Cargando más recursos...',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              // Botón para cargar más
              return Padding(
                padding: EdgeInsets.all(16.w),
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(resourcesProvider.notifier).loadMoreResources(
                            type: _selectedType,
                            location: _selectedLocation,
                          ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text('Cargar más recursos'),
                ),
              );
            }
          }

          final resource = sortedResources[index];
          return ResourceCard(
            resource: resource,
            onTap: () {
              // Navegar al detalle dentro de /home
              context.push('/home/resource/${resource.id}');
            },
            onReserve: () {
              // Navegar directamente al flujo de reserva
              context.push('/booking/${resource.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16.h),
            Text(
              'Cargando recursos...',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Inline ResourceCard removed after refactor.

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64.sp,
              color: AppColors.grey400,
            ),
            SizedBox(height: 16.h),
            Text(
              'No se encontraron recursos',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Intenta ajustar tus filtros o términos de búsqueda',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedType = null;
                  _selectedLocation = null;
                  _searchController.clear();
                });
                _applyFilters();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
              child: Text('Limpiar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: AppColors.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error cargando recursos',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => ref
                  .read(resourcesProvider.notifier)
                  .loadResources(refresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearch(String query) {
    // Debounce con Timer reutilizable
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (_searchController.text.trim() != query.trim()) return; // input cambió
      ref.read(resourcesProvider.notifier).loadResources(
            refresh: true,
            type: _selectedType,
            location: _selectedLocation,
            search: query.trim().isEmpty ? null : query.trim(),
          );
    });
  }

  void _applyFilters({bool sortChanged = false}) {
    final currentQuery = _searchController.text.trim();
    ref.read(resourcesProvider.notifier).loadResources(
          refresh: true,
          type: _selectedType,
          types: _multiTypes.isEmpty ? null : _multiTypes.toList(),
          location: _selectedLocation,
          locations: _multiLocations.isEmpty ? null : _multiLocations.toList(),
          search: currentQuery.isEmpty ? null : currentQuery,
          minPrice: _appliedMinPrice,
          maxPrice: _appliedMaxPrice,
          sort: _sortKey,
        );
    // sortChanged is captured for future enhancement if we cache list before re-fetch.
  }

  void _openAdvancedFilters(List<String> dynamicLocations) {
    // Inicializar rango dinámico (podría venir de stats backend en el futuro)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final types = ResourceType.values;
        final allLocations = <String>{...dynamicLocations, ..._multiLocations};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
                    16.h + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Filtros Avanzados',
                            style: TextStyle(
                                fontSize: 18.sp, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            setModalState(() {
                              _multiTypes.clear();
                              _multiLocations.clear();
                              _priceRange = const RangeValues(0, 500);
                              _appliedMinPrice = null;
                              _appliedMaxPrice = null;
                              _sortKey = null;
                            });
                          },
                        )
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text('Tipos',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        for (final t in types)
                          FilterChip(
                            label: Text(t.displayName,
                                style: TextStyle(fontSize: 12.sp)),
                            selected: _multiTypes.contains(t),
                            onSelected: (sel) => setModalState(() {
                              if (sel) {
                                _multiTypes.add(t);
                              } else {
                                _multiTypes.remove(t);
                              }
                            }),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text('Ubicaciones',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    SizedBox(height: 4.h),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 120.h),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8.w,
                          children: [
                            for (final loc in allLocations)
                              FilterChip(
                                label: Text(loc,
                                    style: TextStyle(fontSize: 12.sp)),
                                selected: _multiLocations.contains(loc),
                                onSelected: (sel) => setModalState(() {
                                  if (sel) {
                                    _multiLocations.add(loc);
                                  } else {
                                    _multiLocations.remove(loc);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text('Rango de Precio (€ / hora)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: 1000,
                      divisions: 100,
                      labels: RangeLabels(
                        _priceRange.start.toStringAsFixed(0),
                        _priceRange.end.toStringAsFixed(0),
                      ),
                      onChanged: (vals) => setModalState(() {
                        _priceRange = vals;
                      }),
                    ),
                    SizedBox(height: 4.h),
                    Text('Ordenar por',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        _buildSortChip(setModalState, 'Precio ↑', 'price_asc'),
                        _buildSortChip(setModalState, 'Precio ↓', 'price_desc'),
                        _buildSortChip(setModalState, 'Nuevos', 'created_desc'),
                        _buildSortChip(
                            setModalState, 'Antiguos', 'created_asc'),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _multiTypes.clear();
                                _multiLocations.clear();
                                _priceRange = const RangeValues(0, 500);
                                _appliedMinPrice = null;
                                _appliedMaxPrice = null;
                                _sortKey = null;
                              });
                            },
                            child: const Text('Limpiar'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Aplicar rango
                              _appliedMinPrice = _priceRange.start > 0
                                  ? _priceRange.start
                                  : null;
                              _appliedMaxPrice = _priceRange.end < 1000
                                  ? _priceRange.end
                                  : null;
                              Navigator.of(context).pop();
                              _applyFilters();
                            },
                            child: const Text('Aplicar'),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(
      void Function(void Function()) setModalState, String label, String key) {
    final selected = _sortKey == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12.sp)),
      selected: selected,
      onSelected: (_) => setModalState(() {
        _sortKey = selected ? null : key;
      }),
    );
  }
}
