import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart';

// Estado para las reservas
class BookingsState {
  final List<BookingModel> bookings;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;
  final BookingStatus? filterStatus;

  const BookingsState({
    this.bookings = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
    this.filterStatus,
  });

  BookingsState copyWith({
    List<BookingModel>? bookings,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
    BookingStatus? filterStatus,
  }) {
    return BookingsState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }

  @override
  String toString() {
    return 'BookingsState(bookings: ${bookings.length}, isLoading: $isLoading, error: $error)';
  }
}

// Notifier para manejar reservas
class BookingsNotifier extends StateNotifier<BookingsState> {
  final ApiService _apiService;
  final Logger _logger = Logger();

  BookingsNotifier(this._apiService) : super(const BookingsState());

  // Normaliza la respuesta del backend para evitar fallos de parseo cuando
  // la reserva incluye un recurso parcial (solo id/name/type/location).
  // Si detectamos que faltan campos requeridos por ResourceModel, removemos
  // el objeto `resource` para que quede en null y no reviente el fromJson.
  Map<String, dynamic> _sanitizeBookingJson(Map<String, dynamic> json) {
    final sanitized = Map<String, dynamic>.from(json);
    final res = sanitized['resource'];
    if (res is Map<String, dynamic>) {
      // Campos que ResourceModel espera en muchas vistas (varios son required)
      const requiredKeys = [
        'id',
        'name',
        'description',
        'type',
        'pricePerHour',
        'images',
        'isActive',
        'createdAt',
        'updatedAt',
        'ownerId',
      ];

      final hasAllRequired = requiredKeys.every(
        (k) => res.containsKey(k) && res[k] != null,
      );

      if (!hasAllRequired) {
        // Si no están todos los campos, preferimos quitar el recurso para
        // no romper el parseo. La UI ya contempla el caso de null.
        sanitized.remove('resource');
      } else {
        // Asegurar que images sea List<String> (puede venir como [{url:..}])
        final imgs = res['images'];
        if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
          res['images'] =
              imgs.map((e) => (e as Map)['url']).whereType<String>().toList();
        }

        // Alinear posibles tipos numéricos a String para ids
        for (final key in ['id', 'ownerId']) {
          final v = res[key];
          if (v is int) res[key] = v.toString();
        }
      }
    }

    // Saneamos usuario incrustado: si falta 'role' u otros requeridos, lo quitamos
    final usr = sanitized['user'];
    if (usr is Map<String, dynamic>) {
      const requiredUserKeys = [
        'id',
        'email',
        'name',
        'role',
        'isActive',
        'createdAt',
        'updatedAt'
      ];
      final hasAll = requiredUserKeys.every(
        (k) => usr.containsKey(k) && usr[k] != null,
      );
      if (!hasAll) {
        sanitized.remove('user');
      }
    }

    // Saneamos pagos: si los items no traen todos los requeridos del modelo móvil,
    // preferimos quitar la lista completa para no romper el parseo.
    final pays = sanitized['payments'];
    if (pays is List) {
      bool valid = true;
      for (final p in pays) {
        if (p is! Map<String, dynamic>) {
          valid = false;
          break;
        }
        const keys = [
          'id',
          'amount',
          'currency',
          'status',
          'createdAt',
          'updatedAt',
          'userId',
          'bookingId'
        ];
        if (!keys.every((k) => p.containsKey(k) && p[k] != null)) {
          valid = false;
          break;
        }
      }
      if (!valid) {
        sanitized.remove('payments');
      }
    }

    // Coerción defensiva de ids de Booking
    for (final key in ['id', 'userId', 'resourceId']) {
      final v = sanitized[key];
      if (v is int) sanitized[key] = v.toString();
    }

    return sanitized;
  }

  // Cargar reservas del usuario
  Future<void> loadBookings({
    BookingStatus? status,
    bool refresh = false,
  }) async {
    if (state.isLoading && !refresh) return;

    // Si es refresh, resetear el estado
    if (refresh) {
      state = BookingsState(
        isLoading: true,
        filterStatus: status,
      );
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final queryParams = <String, dynamic>{
        'page': refresh ? 1 : state.currentPage,
        'limit': 10,
      };

      if (status != null) {
        queryParams['status'] = status.name.toUpperCase();
      }

      final response =
          await _apiService.get('/bookings', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final data = response.data;
        final bookingsList = (data['bookings'] as List)
            .map((json) => BookingModel.fromJson(
                _sanitizeBookingJson(json as Map<String, dynamic>)))
            .toList();

        final pagination = data['pagination'];
        final hasMore = pagination['page'] < pagination['pages'];

        if (refresh) {
          // Si es refresh, reemplazar toda la lista
          state = BookingsState(
            bookings: bookingsList,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
            filterStatus: status,
          );
        } else {
          // Si no es refresh, agregar a la lista existente
          final updatedBookings = [...state.bookings, ...bookingsList];
          state = state.copyWith(
            bookings: updatedBookings,
            isLoading: false,
            hasMore: hasMore,
            currentPage: pagination['page'],
          );
        }

        _logger.i(
            'Reservas cargadas: ${bookingsList.length}, Total: ${state.bookings.length}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Error cargando reservas',
        );
      }
    } on ApiException catch (e) {
      _logger.e('Error API cargando reservas: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: _mapError(e.message),
      );
    } catch (e) {
      _logger.e('Error cargando reservas: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión',
      );
    }
  }

  // Cargar más reservas (paginación)
  Future<void> loadMoreBookings() async {
    if (!state.hasMore || state.isLoading) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(currentPage: nextPage);

    await loadBookings(status: state.filterStatus);
  }

  // Crear nueva reserva
  Future<BookingModel?> createBooking({
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    try {
      _logger.d('Creando reserva para recurso: $resourceId');

      final response = await _apiService.post('/bookings', data: {
        'resourceId': resourceId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      if (response.statusCode == 201) {
        final bookingData = _sanitizeBookingJson(
            response.data['booking'] as Map<String, dynamic>);
        final newBooking = BookingModel.fromJson(bookingData);

        // Agregar la nueva reserva al inicio de la lista
        state = state.copyWith(
          bookings: [newBooking, ...state.bookings],
        );

        _logger.i('Reserva creada exitosamente: ${newBooking.id}');
        return newBooking;
      }
    } on ApiException catch (e) {
      _logger.e('Error API creando reserva: ${e.message}');
      throw ApiException(_mapError(e.message));
    } catch (e) {
      _logger.e('Error creando reserva: $e');
      throw ApiException('Error de conexión');
    }
    return null;
  }

  // Obtener reserva específica
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      _logger.d('Obteniendo reserva: $bookingId');

      final response = await _apiService.get('/bookings/$bookingId');

      if (response.statusCode == 200) {
        final bookingData = _sanitizeBookingJson(
            response.data['booking'] as Map<String, dynamic>);
        final booking = BookingModel.fromJson(bookingData);

        _logger.i('Reserva obtenida: ${booking.id}');
        return booking;
      }
    } on ApiException catch (e) {
      _logger.e('Error API obteniendo reserva: ${e.message}');
    } catch (e) {
      _logger.e('Error obteniendo reserva: $e');
    }
    return null;
  }

  // Cancelar reserva
  Future<bool> cancelBooking(String bookingId) async {
    try {
      _logger.d('Cancelando reserva: $bookingId');
      // Endpoint de cancelación de usuario
      final response = await _apiService.put('/bookings/$bookingId/cancel');

      if (response.statusCode == 200) {
        final updatedBookingData = response.data['booking'];
        final updatedBooking = BookingModel.fromJson(updatedBookingData);

        // Actualizar en la lista local
        final updatedBookings = state.bookings.map((booking) {
          return booking.id == bookingId ? updatedBooking : booking;
        }).toList();

        state = state.copyWith(bookings: updatedBookings);

        _logger.i('Reserva cancelada exitosamente');
        return true;
      }
    } on ApiException catch (e) {
      _logger.e('Error API cancelando reserva: ${e.message}');
    } catch (e) {
      _logger.e('Error cancelando reserva: $e');
    }
    return false;
  }

  // Validar disponibilidad de horario
  Future<bool> checkAvailability({
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      _logger.d('Verificando disponibilidad para recurso: $resourceId');

      final response =
          await _apiService.post('/bookings/check-availability', data: {
        'resourceId': resourceId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      });

      if (response.statusCode == 200) {
        final isAvailable = response.data['available'] as bool;
        _logger.i('Disponibilidad: $isAvailable');
        return isAvailable;
      } else {
        final code = response.statusCode ?? 0;
        final serverMsg =
            (response.data is Map) ? (response.data['error'] as String?) : null;
        switch (code) {
          case 409:
            throw ApiException('Horario no disponible (conflicto).');
          case 422:
            throw ApiException(
                serverMsg ?? 'Rango inválido: verifica fecha/hora futuras.');
          case 400:
            throw ApiException(
                serverMsg ?? 'Parámetros inválidos para disponibilidad.');
          default:
            throw ApiException(
                serverMsg ?? 'No se pudo verificar disponibilidad.');
        }
      }
    } on ApiException catch (e) {
      _logger.e('Error API verificando disponibilidad: ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error verificando disponibilidad: $e');
      throw ApiException('Error de conexión al verificar disponibilidad');
    }
  }

  String _mapError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('409') || lower.contains('conflict')) {
      return 'Horario no disponible (conflicto)';
    }
    if (lower.contains('400')) return 'Datos inválidos';
    if (lower.contains('404')) return 'Recurso o reserva no encontrada';
    if (lower.contains('500')) return 'Error interno del servidor';
    return raw;
  }

  // Limpiar errores
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Resetear estado
  void reset() {
    state = const BookingsState();
  }
}

// Provider para el BookingsNotifier
final bookingsProvider =
    StateNotifierProvider<BookingsNotifier, BookingsState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return BookingsNotifier(apiService);
});

// Provider para obtener una reserva específica
final bookingProvider =
    FutureProvider.family<BookingModel?, String>((ref, bookingId) {
  final notifier = ref.read(bookingsProvider.notifier);
  return notifier.getBooking(bookingId);
});

// Provider para filtrar reservas por estado
final bookingsByStatusProvider =
    Provider.family<List<BookingModel>, BookingStatus?>((ref, status) {
  final bookings = ref.watch(bookingsProvider).bookings;

  if (status == null) return bookings;

  return bookings.where((booking) => booking.status == status).toList();
});

// Provider para reservas activas (confirmadas y en progreso)
final activeBookingsProvider = Provider<List<BookingModel>>((ref) {
  final bookings = ref.watch(bookingsProvider).bookings;

  return bookings
      .where((booking) =>
          booking.status == BookingStatus.confirmed ||
          booking.status == BookingStatus.inProgress)
      .toList();
});

// Provider para reservas pendientes
final pendingBookingsProvider = Provider<List<BookingModel>>((ref) {
  final bookings = ref.watch(bookingsProvider).bookings;

  return bookings
      .where((booking) => booking.status == BookingStatus.pending)
      .toList();
});

// Provider para reservas completadas
final completedBookingsProvider = Provider<List<BookingModel>>((ref) {
  final bookings = ref.watch(bookingsProvider).bookings;

  return bookings
      .where((booking) =>
          booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.refunded)
      .toList();
});

// Provider para estadísticas de reservas del usuario
final bookingStatsProvider = Provider<Map<String, int>>((ref) {
  final bookings = ref.watch(bookingsProvider).bookings;

  return {
    'total': bookings.length,
    'pending': bookings.where((b) => b.status == BookingStatus.pending).length,
    'confirmed':
        bookings.where((b) => b.status == BookingStatus.confirmed).length,
    'inProgress':
        bookings.where((b) => b.status == BookingStatus.inProgress).length,
    'completed':
        bookings.where((b) => b.status == BookingStatus.completed).length,
    'cancelled':
        bookings.where((b) => b.status == BookingStatus.cancelled).length,
  };
});
