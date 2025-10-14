import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';

// Dummy bookings provider using Map for demonstration
final bookingsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return [
    {
      'id': '1',
      'status': 'active',
      'resourceName': 'Almacén Norte - Sector A',
      'price': 25.0,
      'startDate': DateTime.now(),
      'endDate': DateTime.now().add(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'status': 'pending',
      'resourceName': 'Máquina Láser Pro',
      'price': 40.0,
      'startDate': DateTime.now().add(const Duration(days: 1)),
      'endDate': DateTime.now().add(const Duration(days: 1, hours: 1)),
    },
  ];
});

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Activas'),
            Tab(text: 'Pendientes'),
            Tab(text: 'Completadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('all'),
          _buildBookingsList('active'),
          _buildBookingsList('pending'),
          _buildBookingsList('completed'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String filter) {
    final bookings = ref.watch(bookingsProvider);
    final filtered = filter == 'all'
        ? bookings
        : bookings.where((b) => b['status'] == filter).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(filter);
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildBookingCard(filtered[i]),
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
              ElevatedButton(
                onPressed: () {
                  context.go('/home/search');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                ),
                child: Text(
                  'Explorar Recursos',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Método para construir una tarjeta de reserva (para uso futuro)
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: booking['status'] == 'active'
                        ? AppColors.success.withOpacity(0.1)
                        : booking['status'] == 'pending'
                            ? AppColors.info.withOpacity(0.1)
                            : AppColors.grey100,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    (booking['status'] as String).toUpperCase(),
                    style: TextStyle(
                      color: booking['status'] == 'active'
                          ? AppColors.success
                          : booking['status'] == 'pending'
                              ? AppColors.info
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '€${(booking['price'] as double).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Nombre del recurso
            Text(
              booking['resourceName'],
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            // Fechas
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: AppColors.grey500, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  '${(booking['startDate'] as DateTime).day}/${(booking['startDate'] as DateTime).month}/${(booking['startDate'] as DateTime).year} - '
                  '${(booking['endDate'] as DateTime).day}/${(booking['endDate'] as DateTime).month}/${(booking['endDate'] as DateTime).year}',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            // Duración
            Row(
              children: [
                Icon(Icons.access_time_outlined, color: AppColors.grey500, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  '${((booking['endDate'] as DateTime).difference(booking['startDate'] as DateTime).inHours)} horas',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Acciones (ejemplo)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implementar detalles de reserva
                    },
                    child: const Text('Ver Detalles'),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implementar cancelación
                    },
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
