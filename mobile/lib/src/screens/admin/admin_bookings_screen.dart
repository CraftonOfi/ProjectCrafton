import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';
import '../../models/booking_model.dart';
import '../../models/booking_status_ui.dart';
import '../../providers/admin_bookings_provider.dart';

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminBookingsProvider.notifier).loadAll(refresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBookingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas (Admin)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref
                .read(adminBookingsProvider.notifier)
                .loadAll(refresh: true, status: state.filterStatus),
            icon: const Icon(Icons.refresh),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Todas'),
            Tab(text: 'Pendientes'),
            Tab(text: 'Activas'),
            Tab(text: 'Cierre'),
          ],
          onTap: (i) {
            BookingStatus? s;
            if (i == 1) s = BookingStatus.pending;
            if (i == 2)
              s = BookingStatus.confirmed; // incluirá inProgress en UI
            if (i == 3)
              s = BookingStatus
                  .completed; // incluirá canceladas/refundadas en UI
            ref
                .read(adminBookingsProvider.notifier)
                .loadAll(refresh: true, status: s);
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(state.bookings),
          _buildList(state.bookings
              .where((b) => b.status == BookingStatus.pending)
              .toList()),
          _buildList(state.bookings
              .where((b) =>
                  b.status == BookingStatus.confirmed ||
                  b.status == BookingStatus.inProgress)
              .toList()),
          _buildList(state.bookings
              .where((b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.cancelled ||
                  b.status == BookingStatus.refunded)
              .toList()),
        ],
      ),
    );
  }

  Widget _buildList(List<BookingModel> list) {
    final state = ref.watch(adminBookingsProvider);
    if (state.isLoading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text('Sin reservas para este filtro',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(adminBookingsProvider.notifier)
            .loadAll(refresh: true, status: state.filterStatus);
      },
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: list.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= list.length) {
            ref.read(adminBookingsProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final b = list[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      bookingStatusChip(b.status),
                      Text(b.formattedPrice,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Builder(builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      b.resource?.name ?? 'Recurso #${b.resourceId}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                  SizedBox(height: 4.h),
                  Row(children: [
                    Icon(Icons.schedule_outlined,
                        size: 16.sp, color: AppColors.grey500),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        '${_fmt(b.startTime)} - ${_fmt(b.endTime)}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  ]),
                  SizedBox(height: 12.h),
                  _buildAdminActions(b),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminActions(BookingModel b) {
    final notifier = ref.read(adminBookingsProvider.notifier);
    final adminState = ref.read(adminBookingsProvider);
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        if (b.status == BookingStatus.pending)
          _chipAction('Confirmar', AppColors.info, () async {
            final ok =
                await notifier.updateStatus(b.id, BookingStatus.confirmed);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      ok ? 'Reserva confirmada' : 'No se pudo actualizar')),
            );
            if (ok) {
              await ref
                  .read(adminBookingsProvider.notifier)
                  .loadAll(refresh: true, status: adminState.filterStatus);
            }
          }),
        if (b.status == BookingStatus.confirmed)
          _chipAction('Marcar en curso', AppColors.secondary, () async {
            final ok =
                await notifier.updateStatus(b.id, BookingStatus.inProgress);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(ok ? 'Marcada en curso' : 'No se pudo actualizar')),
            );
            if (ok) {
              await ref
                  .read(adminBookingsProvider.notifier)
                  .loadAll(refresh: true, status: adminState.filterStatus);
            }
          }),
        if (b.status == BookingStatus.inProgress)
          _chipAction('Completar', AppColors.success, () async {
            final ok =
                await notifier.updateStatus(b.id, BookingStatus.completed);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      ok ? 'Reserva completada' : 'No se pudo actualizar')),
            );
            if (ok) {
              await ref
                  .read(adminBookingsProvider.notifier)
                  .loadAll(refresh: true, status: adminState.filterStatus);
            }
          }),
        if (b.status != BookingStatus.cancelled &&
            b.status != BookingStatus.completed)
          _chipAction('Cancelar', AppColors.error, () async {
            final ok =
                await notifier.updateStatus(b.id, BookingStatus.cancelled);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(ok ? 'Reserva cancelada' : 'No se pudo actualizar')),
            );
            if (ok) {
              await ref
                  .read(adminBookingsProvider.notifier)
                  .loadAll(refresh: true, status: adminState.filterStatus);
            }
          }),
      ],
    );
  }

  Widget _chipAction(String text, Color color, VoidCallback onTap) {
    return ActionChip(
      label: Text(text),
      labelStyle:
          TextStyle(color: _textFor(color), fontWeight: FontWeight.w600),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      onPressed: onTap,
    );
  }

  String _fmt(DateTime d) {
    final mm = d.minute.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    return '${d.day}/${d.month} $hh:$mm';
  }

  Color _textFor(Color c) {
    // simple contrast helper
    return Colors.black; // action chips use tinted bg; black reads well
  }
}
