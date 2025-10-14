import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme_config.dart';
import '../../models/booking_model.dart';
import '../../models/booking_status_ui.dart';
import '../../providers/bookings_provider.dart';
import '../../widgets/custom_button.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Cargar reservas al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingsProvider.notifier).loadBookings(refresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsState = ref.watch(bookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(bookingsProvider.notifier).loadBookings(refresh: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(text: 'Todas (${bookingsState.bookings.length})'),
            Tab(text: 'Activas (${ref.watch(activeBookingsProvider).length})'),
            Tab(
                text:
                    'Pendientes (${ref.watch(pendingBookingsProvider).length})'),
            Tab(
                text:
                    'Completadas (${ref.watch(completedBookingsProvider).length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(bookingsState.bookings, 'all'),
          _buildBookingsList(ref.watch(activeBookingsProvider), 'active'),
          _buildBookingsList(ref.watch(pendingBookingsProvider), 'pending'),
          _buildBookingsList(ref.watch(completedBookingsProvider), 'completed'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, String filter) {
    final bookingsState = ref.watch(bookingsProvider);

    if (bookingsState.isLoading && bookings.isEmpty) {
      return _buildLoadingState();
    }

    if (bookingsState.error != null && bookings.isEmpty) {
      return _buildErrorState(bookingsState.error!);
    }

    if (bookings.isEmpty) {
      return _buildEmptyState(filter);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(bookingsProvider.notifier).loadBookings(refresh: true);
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(16.w),
            sliver: SliverList.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) =>
                  _buildBookingCard(bookings[index]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: bookingsState.hasMore
                    ? (bookingsState.isLoading
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () => ref
                                .read(bookingsProvider.notifier)
                                .loadMoreBookings(),
                            child: const Text('Cargar más'),
                          ))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 6,
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 18.h,
                  width: 120.w,
                  color: AppColors.grey300.withOpacity(0.25)),
              SizedBox(height: 8.h),
              Container(
                  height: 14.h,
                  width: 180.w,
                  color: AppColors.grey300.withOpacity(0.25)),
              SizedBox(height: 6.h),
              Container(
                  height: 12.h,
                  width: 220.w,
                  color: AppColors.grey300.withOpacity(0.25)),
            ],
          ),
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
              'Error cargando reservas',
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
            SizedBox(height: 24.h),
            CustomButton(
              text: 'Reintentar',
              onPressed: () {
                ref.read(bookingsProvider.notifier).loadBookings(refresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String title;
    String description;
    IconData icon;

    switch (filter) {
      case 'active':
        title = 'No tienes reservas activas';
        description = 'Tus reservas confirmadas y en progreso aparecerán aquí';
        icon = Icons.event_available_outlined;
        break;
      case 'pending':
        title = 'No tienes reservas pendientes';
        description = 'Las reservas que requieren confirmación aparecerán aquí';
        icon = Icons.pending_outlined;
        break;
      case 'completed':
        title = 'No tienes reservas completadas';
        description = 'Tu historial de reservas finalizadas aparecerá aquí';
        icon = Icons.history_outlined;
        break;
      default:
        title = 'No tienes reservas';
        description = 'Explora nuestros recursos y haz tu primera reserva';
        icon = Icons.calendar_today_outlined;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: const BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48.sp,
                color: AppColors.grey400,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              description,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            if (filter == 'all') ...[
              CustomButton(
                text: 'Explorar Recursos',
                onPressed: () {
                  context.go('/home/search');
                },
                icon: Icons.search,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        onTap: () {
          _showBookingDetails(booking);
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estado y precio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  bookingStatusChip(booking.status),
                  Text(
                    booking.formattedPrice,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Nombre del recurso
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  booking.resource?.name ?? 'Recurso no disponible',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }),

              SizedBox(height: 8.h),

              // Fechas y horarios
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16.sp,
                    color: AppColors.grey500,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      _formatBookingDateTime(booking),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4.h),

              // Duración
              Row(
                children: [
                  Icon(
                    Icons.timelapse_outlined,
                    size: 16.sp,
                    color: AppColors.grey500,
                  ),
                  SizedBox(width: 4.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      border:
                          Border.all(color: AppColors.info.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      'Duración: ${booking.formattedDuration}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.grey800
                        : AppColors.grey50,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    booking.notes!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              SizedBox(height: 12.h),

              // Acciones
              _buildBookingActions(booking),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingActions(BookingModel booking) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showBookingDetails(booking),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Ver Detalles',
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        if (booking.canBeCancelled) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showCancelDialog(booking),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (booking.status == BookingStatus.cancelled ||
                    booking.status == BookingStatus.completed) {
                  final resourceId = booking.resourceId;
                  context.go('/booking/$resourceId');
                } else {
                  _showBookingDetails(booking);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: booking.status == BookingStatus.cancelled ||
                        booking.status == BookingStatus.completed
                    ? AppColors.primary
                    : AppColors.grey400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                _getActionText(booking.status),
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // _getStatusColor no longer needed (using bookingStatusChip helper)

  String _getActionText(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return 'Reservar otra vez';
      case BookingStatus.cancelled:
        return 'Reservar otra vez';
      default:
        return 'Ver más';
    }
  }

  String _formatBookingDateTime(BookingModel booking) {
    final start = booking.startTime;
    final end = booking.endTime;

    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];

    if (start.day == end.day &&
        start.month == end.month &&
        start.year == end.year) {
      // Mismo día
      return '${start.day} ${months[start.month - 1]} ${start.year}, ${_formatTime(start)} - ${_formatTime(end)}';
    } else {
      // Días diferentes
      return '${start.day} ${months[start.month - 1]} ${_formatTime(start)} - ${end.day} ${months[end.month - 1]} ${_formatTime(end)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showBookingDetails(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingDetailsBottomSheet(booking: booking),
    );
  }

  void _showCancelDialog(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
          title: Text(
            'Cancelar Reserva',
            style: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres cancelar la reserva de "${booking.resource?.name}"?',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'No',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final success = await ref
                    .read(bookingsProvider.notifier)
                    .cancelBooking(booking.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Reserva cancelada exitosamente'
                          : 'Error cancelando la reserva',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );
  }
}

// Bottom Sheet para detalles de la reserva
class BookingDetailsBottomSheet extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Título
          Text(
            'Detalles de la Reserva',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 20.h),

          // Contenido scrolleable
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado
                  bookingStatusChip(booking.status),

                  SizedBox(height: 20.h),

                  // Información del recurso
                  if (booking.resource != null) ...[
                    _buildDetailSection(
                      'Recurso',
                      [
                        _buildDetailRow('Nombre', booking.resource!.name),
                        _buildDetailRow(
                            'Tipo', booking.resource!.typeDisplayName),
                        if (booking.resource!.hasLocation)
                          _buildDetailRow(
                              'Ubicación', booking.resource!.location!),
                      ],
                    ),
                    SizedBox(height: 20.h),
                  ],

                  // Información de la reserva
                  _buildDetailSection(
                    'Detalles de la Reserva',
                    [
                      _buildDetailRow('ID de Reserva', booking.id),
                      _buildDetailRow('Fecha de Inicio',
                          _formatDateTime(booking.startTime)),
                      _buildDetailRow(
                          'Fecha de Fin', _formatDateTime(booking.endTime)),
                      _buildDetailRow('Duración', booking.formattedDuration),
                      _buildDetailRow('Precio Total', booking.formattedPrice),
                    ],
                  ),

                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _buildDetailSection(
                      'Notas',
                      [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.grey50,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            booking.notes!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 20.h),

                  // Información de fechas del sistema
                  _buildDetailSection(
                    'Información del Sistema',
                    [
                      _buildDetailRow(
                          'Creada el', _formatDateTime(booking.createdAt)),
                      _buildDetailRow('Última actualización',
                          _formatDateTime(booking.updatedAt)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Botón de cerrar
          CustomButton(
            text: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.confirmed:
        return AppColors.info;
      case BookingStatus.inProgress:
        return AppColors.success;
      case BookingStatus.completed:
        return AppColors.grey600;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.refunded:
        return AppColors.secondary;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];

    return '${dateTime.day} de ${months[dateTime.month - 1]} de ${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
