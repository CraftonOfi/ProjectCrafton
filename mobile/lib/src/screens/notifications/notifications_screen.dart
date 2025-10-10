import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';
import '../../providers/notifications_provider.dart';
import '../../utils/format.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _onlyUnread = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(notificationsProvider.notifier)
          .load(refresh: true, unreadOnly: _onlyUnread);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: _onlyUnread ? 'Mostrar todas' : 'Solo no leídas',
            onPressed: state.isLoading
                ? null
                : () async {
                    setState(() => _onlyUnread = !_onlyUnread);
                    await ref
                        .read(notificationsProvider.notifier)
                        .load(refresh: true, unreadOnly: _onlyUnread);
                  },
            icon: Icon(
              _onlyUnread
                  ? Icons.mark_email_unread
                  : Icons.mark_email_unread_outlined,
            ),
          ),
          IconButton(
            onPressed: state.unreadCount == 0 || state.isLoading
                ? null
                : () async {
                    await ref
                        .read(notificationsProvider.notifier)
                        .markAllRead();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Todas marcadas como leídas')),
                    );
                  },
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Marcar todas como leídas',
          )
        ],
      ),
      body: SafeArea(
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(notificationsProvider.notifier)
                      .load(refresh: true, unreadOnly: _onlyUnread);
                },
                child: Column(
                  children: [
                    if (state.error != null)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16.sp, color: AppColors.warning),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(color: AppColors.warning),
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(notificationsProvider.notifier)
                                  .load(refresh: true),
                              child: const Text('Reintentar'),
                            )
                          ],
                        ),
                      ),
                    if (state.items.isEmpty)
                      Expanded(child: _buildEmpty())
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(16.w),
                          itemCount:
                              state.items.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.items.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Center(
                                  child: state.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : TextButton(
                                          onPressed: () => ref
                                              .read(notificationsProvider
                                                  .notifier)
                                              .loadMore(),
                                          child: const Text('Cargar más'),
                                        ),
                                ),
                              );
                            }
                            final n = state.items[index];
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final translated = _translateMessage(n.message);
                            return Dismissible(
                              key: ValueKey(n.id),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: const Icon(
                                    Icons.mark_email_read_outlined,
                                    color: AppColors.success),
                              ),
                              secondaryBackground: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: const Icon(
                                    Icons.mark_email_read_outlined,
                                    color: AppColors.success),
                              ),
                              confirmDismiss: (_) async {
                                if (n.read) return false;
                                await ref
                                    .read(notificationsProvider.notifier)
                                    .markRead(n.id);
                                return false; // no borrar, solo marcar
                              },
                              child: Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color:
                                      isDark ? AppColors.grey800 : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                      color: isDark
                                          ? (n.read
                                              ? AppColors.grey600
                                              : AppColors.primary
                                                  .withOpacity(0.55))
                                          : (n.read
                                              ? AppColors.grey200
                                              : AppColors.primary
                                                  .withOpacity(0.45))),
                                  boxShadow: isDark
                                      ? [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2))
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _iconFor(n.type),
                                      color: n.read
                                          ? AppColors.grey500
                                          : AppColors.primary,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? (n.read
                                                            ? AppColors
                                                                .textSecondaryDark
                                                            : AppColors
                                                                .textPrimaryDark)
                                                        : (n.read
                                                            ? AppColors
                                                                .textSecondary
                                                            : AppColors
                                                                .textPrimary),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                Formatters.shortDateTime(
                                                    n.createdAt),
                                                style: TextStyle(
                                                    fontSize: 11.sp,
                                                    color: isDark
                                                        ? AppColors
                                                            .textSecondaryDark
                                                        : AppColors
                                                            .textSecondary),
                                              )
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(translated,
                                              style: TextStyle(
                                                  height: 1.25,
                                                  color: isDark
                                                      ? AppColors
                                                          .textPrimaryDark
                                                      : AppColors.textPrimary)),
                                          if (!n.read)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: () => ref
                                                    .read(notificationsProvider
                                                        .notifier)
                                                    .markRead(n.id),
                                                child:
                                                    const Text('Marcar leída'),
                                              ),
                                            )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64.sp, color: AppColors.grey400),
          SizedBox(height: 12.h),
          const Text('No tienes notificaciones'),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'BOOKING_CONFIRMED':
        return Icons.event_available_outlined;
      case 'BOOKING_REMINDER':
        return Icons.alarm_on_outlined;
      case 'PAYMENT_RECEIVED':
        return Icons.attach_money;
      case 'MAINTENANCE_ALERT':
        return Icons.build_circle_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _translateMessage(String msg) {
    return msg
        .replaceAll('IN_PROGRESS', 'EN CURSO')
        .replaceAll('COMPLETED', 'COMPLETADA')
        .replaceAll('PENDING', 'PENDIENTE')
        .replaceAll('CONFIRMED', 'CONFIRMADA')
        .replaceAll('CANCELLED', 'CANCELADA')
        .replaceAll('REFUNDED', 'REEMBOLSADA');
  }
}
