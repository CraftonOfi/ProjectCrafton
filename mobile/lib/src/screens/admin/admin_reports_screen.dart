import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard for CSV export
import 'dart:async';
import 'dart:ui'
    show PointerDeviceKind; // Drag con mouse/touch en scroll horizontal
import 'dart:math' as math; // Sparkline
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';
import '../../providers/admin_reports_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _ranges = [7, 15, 30, 90, 120, 365];

  // Scroll ingresos
  final ScrollController _revScroll = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  // Sparkline animation
  late final AnimationController _sparkCtl;
  double _sparkProgress = 0;
  int _lastSeriesHash = 0;
  int _lastRangeDays = 0; // para detectar cambio de rango y forzar animación

  // Visibilidad de controles (flechas) con auto-hide por inactividad
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _sparkCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() => _sparkProgress = _sparkCtl.value);
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = ref.read(adminReportsProvider.notifier);
      n.load();
      n.loadRange(30);
    });
    _revScroll.addListener(_onRevScroll);
  }

  void _onRevScroll() {
    if (!_revScroll.hasClients) return;
    final m = _revScroll.position.maxScrollExtent;
    final o = _revScroll.offset;
    final left = o > 4;
    final right = o < (m - 4);
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
    _bumpControlsVisibility();
  }

  void _bumpControlsVisibility() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _revScroll.removeListener(_onRevScroll);
    _revScroll.dispose();
    _sparkCtl.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              final n = ref.read(adminReportsProvider.notifier);
              n.load();
              n.loadRange(state.rangeDays);
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final n = ref.read(adminReportsProvider.notifier);
          await n.load();
          await n.loadRange(state.rangeDays);
        },
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminSummaryState state) {
    if (state.loading && state.data == null) {
      return ListView(children: const [
        SizedBox(height: 200),
        Center(child: CircularProgressIndicator())
      ]);
    }
    if (state.error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.sms_failed_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 8),
        Center(
          child: Text(state.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ]);
    }
    if (state.data == null || state.data!.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 140),
        const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 12),
        Center(
            child: Text('Aún no hay datos',
                style: Theme.of(context).textTheme.titleMedium)),
      ]);
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _kpiSummaryRow(context, state.data ?? const {}),
        SizedBox(height: 12.h),
        _rangeSelector(context, state),
        SizedBox(height: 12.h),
        _bookingsRangeCard(context, state),
        SizedBox(height: 12.h),
        _revenueRangeCard(context, state),
        SizedBox(height: 16.h),
        _topResources(context, state.data ?? const {}),
      ],
    );
  }

  // --- KPI header ---
  Widget _kpiTile(String title, String value, IconData icon, Color color,
      {String? subtitle, VoidCallback? onTap}) {
    return Semantics(
      label: title,
      value: subtitle != null ? '$value · $subtitle' : value,
      button: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.22),
                        color.withOpacity(0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: title,
                    child: Icon(icon, color: color, size: 20.sp),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.textSecondary)),
                      SizedBox(height: 2.h),
                      Text(value,
                          style: TextStyle(
                              fontSize: 19.sp, fontWeight: FontWeight.w800)),
                      if (subtitle != null) ...[
                        SizedBox(height: 1.h),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textSecondary)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, Map<String, dynamic> data) {
    final users = (data['users'] as Map?) ?? {};
    final bookings = (data['bookings'] as Map?) ?? {};

    final usersTotal = users['total']?.toString() ?? '0';
    final usersActive = users['active']?.toString() ?? '0';
    final byStatus =
        (bookings['byStatus'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Pendientes = PENDING + CONFIRMED (reservas aún no iniciadas)
    final intPending =
        (byStatus['PENDING'] ?? 0) + (byStatus['CONFIRMED'] ?? 0);
    final totalBookings = bookings['total'] ?? 0;
    final double activePct = (num.tryParse(usersActive) ?? 0) == 0 ||
            (num.tryParse(usersTotal) ?? 0) == 0
        ? 0
        : ((num.tryParse(usersActive) ?? 0) / (num.tryParse(usersTotal) ?? 1)) *
            100.0;
    final double pendingPct =
        totalBookings == 0 ? 0 : intPending / (totalBookings as num) * 100.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _kpiTile(
          'Usuarios',
          usersTotal,
          Icons.people_alt_outlined,
          AppColors.info,
          subtitle: 'Activos: $usersActive (${activePct.toStringAsFixed(0)}%)',
          onTap: () => _openUsersBreakdown(context, users),
        ),
        _kpiTile(
          'Activos',
          usersActive,
          Icons.verified_user_outlined,
          AppColors.success,
          subtitle: 'de $usersTotal usuarios',
          onTap: () => _openUsersBreakdown(context, users),
        ),
        _kpiTile(
          'Pendientes',
          intPending.toString(),
          Icons.pending_actions_outlined,
          AppColors.primaryLight,
          subtitle: totalBookings == 0
              ? null
              : '${pendingPct.toStringAsFixed(0)}% del total',
          onTap: () => _openBookingsBreakdown(context, bookings, 'Reservas'),
        ),
      ],
    );
  }

  // Nueva disposición compacta en una sola card con 2 columnas (Usuarios/Activos)
  Widget _kpiSummaryRow(BuildContext context, Map<String, dynamic> data) {
    final users = (data['users'] as Map?) ?? {};
    final usersTotal = users['total']?.toString() ?? '0';
    final usersActive = users['active']?.toString() ?? '0';
    final double activePct = (num.tryParse(usersActive) ?? 0) == 0 ||
            (num.tryParse(usersTotal) ?? 0) == 0
        ? 0
        : ((num.tryParse(usersActive) ?? 0) / (num.tryParse(usersTotal) ?? 1)) *
            100.0;

    Widget item(IconData icon, Color color, String title, String value,
        String? sub, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.22),
                        color.withOpacity(0.08)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 18.sp),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.textSecondary)),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(value,
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800)),
                          if (sub != null) ...[
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.textSecondary)),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Row(
        children: [
          item(
            Icons.verified_user_outlined,
            AppColors.success,
            'Activos',
            usersActive,
            'de $usersTotal',
            () => _openUsersBreakdown(context, users),
          ),
          Container(
              width: 1,
              height: 48.h,
              color: Theme.of(context).dividerColor.withOpacity(0.08)),
          item(
            Icons.people_alt_outlined,
            AppColors.info,
            'Usuarios',
            usersTotal,
            'Activos ${activePct.toStringAsFixed(0)}%',
            () => _openUsersBreakdown(context, users),
          ),
        ],
      ),
    );
  }

  void _openUsersBreakdown(BuildContext context, Map users) {
    final total = users['total']?.toString() ?? '0';
    final active = users['active']?.toString() ?? '0';
    final t = (num.tryParse(total) ?? 0);
    final a = (num.tryParse(active) ?? 0);
    final pct = t > 0 ? (a / t * 100.0) : 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuarios — Resumen',
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 12.h),
              _rowItem('Total', total),
              _rowItem('Activos', active),
              _rowItem('Porcentaje activos', '${pct.toStringAsFixed(1)}%'),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  // --- Range selector ---
  Widget _rangeSelector(BuildContext context, AdminSummaryState state) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_outlined,
                    size: 18.sp, color: AppColors.info),
                SizedBox(width: 6.w),
                Text('Rango', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(width: 8.w),
                Text('elige periodo',
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.textSecondary)),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: _ranges
                  .map((d) => ChoiceChip(
                        label: Text(d == 365 ? '1 año' : '${d}d'),
                        selected: state.rangeDays == d,
                        onSelected: (sel) {
                          if (sel) {
                            ref
                                .read(adminReportsProvider.notifier)
                                .loadRange(d);
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bookings card ---
  Widget _bookingsRangeCard(BuildContext context, AdminSummaryState state) {
    final totalAll = (state.data?['bookings']?['total'] ?? 0).toString();
    final rangeCount = (state.rangeData?['bookings']?['count'] ?? 0).toString();
    final byStatus = (state.rangeData?['bookings']?['byStatus'] as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available_outlined,
                    color: AppColors.primary, size: 22.sp),
                SizedBox(width: 8.w),
                Text('Reservas',
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Histórico: $totalAll',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.sp)),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
                'Últimos ${state.rangeDays == 365 ? '12 meses' : '${state.rangeDays} días'}',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
            SizedBox(height: 8.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Text(
                rangeCount,
                key: ValueKey('${state.rangeDays}-bk-$rangeCount'),
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
            ),
            if (byStatus.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  if (byStatus.containsKey('COMPLETED'))
                    _statusPill(
                        'Completada', byStatus['COMPLETED'], AppColors.success),
                  if (byStatus.containsKey('CONFIRMED'))
                    _statusPill(
                        'Confirmada', byStatus['CONFIRMED'], AppColors.info),
                  if (byStatus.containsKey('IN_PROGRESS'))
                    _statusPill('En curso', byStatus['IN_PROGRESS'],
                        AppColors.primaryLight),
                  if (byStatus.containsKey('PENDING'))
                    _statusPill(
                        'Pendiente', byStatus['PENDING'], AppColors.warning),
                  if (byStatus.containsKey('CANCELLED'))
                    _statusPill(
                        'Cancelada', byStatus['CANCELLED'], AppColors.error),
                  if (byStatus.containsKey('REFUNDED'))
                    _statusPill(
                        'Reembolsada', byStatus['REFUNDED'], AppColors.accent),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, dynamic value, Color color) {
    final v = (value ?? 0).toString();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(fontSize: 12.sp)),
          SizedBox(width: 6.w),
          Text(v,
              style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // --- Revenue card ---
  Widget _revenueRangeCard(BuildContext context, AdminSummaryState state) {
    String fmt2(dynamic v) => (v is num)
        ? v.toStringAsFixed(2)
        : (num.tryParse('$v')?.toStringAsFixed(2) ?? '0.00');
    final totalAll = fmt2(state.data?['payments']?['revenueTotal'] ?? 0);
    final rawRange = (state.rangeData?['payments']?['revenue'] ?? 0) as num;
    final revenueRange = fmt2(rawRange);
    final avgPerDay =
        state.rangeDays > 0 ? fmt2(rawRange / state.rangeDays) : '0.00';
    final series =
        (state.rangeData?['payments']?['series'] as List?)?.cast<Map>() ??
            const [];

    final forceRangeChange = state.rangeDays != _lastRangeDays;
    _maybeAnimateSeries(series, force: forceRangeChange);
    _lastRangeDays = state.rangeDays;

    double variationPct = 0;
    if (series.length > 1) {
      final first = (series.first['amount'] as num).toDouble();
      final last = (series.last['amount'] as num).toDouble();
      if (first != 0) variationPct = ((last - first) / first) * 100.0;
    }
    final trendColor = variationPct > 0
        ? AppColors.success
        : (variationPct < 0 ? AppColors.error : AppColors.accent);
    final trendIcon = variationPct > 0
        ? Icons.trending_up
        : (variationPct < 0 ? Icons.trending_down : Icons.horizontal_rule);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    color: AppColors.accent, size: 24.sp),
                SizedBox(width: 10.w),
                Text('Ingresos',
                    style: TextStyle(
                        fontSize: 20.sp, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (series.isNotEmpty)
                  IconButton(
                    tooltip: 'Exportar CSV',
                    icon: const Icon(Icons.download_outlined, size: 20),
                    onPressed: () =>
                        _exportCsv(context, series, state.rangeDays),
                  ),
              ],
            ),
            SizedBox(height: 6.h),
            Text('Total histórico: €$totalAll',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4.h),
            Text(
                'Últimos ${state.rangeDays == 365 ? '12 meses' : '${state.rangeDays} días'}',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14.sp)),
            SizedBox(height: 8.h),
            // Insights compactos
            Row(
              children: [
                _insightPill(
                    'Variación',
                    '${variationPct > 0 ? '+' : ''}${variationPct.toStringAsFixed(1)}%',
                    trendColor),
                SizedBox(width: 8.w),
                _insightPill('Promedio/día', '€$avgPerDay', AppColors.info),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Text('€$revenueRange',
                  key: ValueKey('${state.rangeDays}-rev-$revenueRange'),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style:
                      TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800)),
            ),
            SizedBox(height: 4.h),
            Text('Promedio por día: €$avgPerDay',
                style:
                    TextStyle(fontSize: 13.sp, color: AppColors.textSecondary)),
            SizedBox(height: 4.h),
            if (series.length > 1)
              Row(
                children: [
                  Icon(trendIcon, size: 16.sp, color: trendColor),
                  SizedBox(width: 4.w),
                  Text(
                    '${variationPct > 0 ? '+' : ''}${variationPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: trendColor),
                  ),
                ],
              ),
            SizedBox(height: 8.h),
            if (series.isEmpty)
              Text('Sin ingresos en el rango seleccionado.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary))
            else
              _revenueSeries(context, series,
                  sparkColor: trendColor == AppColors.accent
                      ? AppColors.accent
                      : trendColor),
          ],
        ),
      ),
    );
  }

  Widget _insightPill(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
          SizedBox(width: 6.w),
          Text(value,
              style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // --- Top resources ---
  Widget _topResources(BuildContext context, Map<String, dynamic> data) {
    final top = (data['topResources'] as List?)?.cast<Map>() ?? const [];
    if (top.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top recursos por reservas',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8.h),
            ...top.map((r) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      const Icon(Icons.star_border_purple500_rounded,
                          color: AppColors.accent),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(r['name']?.toString() ?? '—')),
                      Text('x${r['count']}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  void _openRevenueBreakdown(BuildContext context, Map payments, String title) {
    String fmt2(dynamic v) => (v is num)
        ? v.toStringAsFixed(2)
        : (num.tryParse('$v')?.toStringAsFixed(2) ?? '0.00');
    final total = fmt2(payments['revenueTotal'] ?? 0);
    final d30 = fmt2(payments['revenueLast30Days'] ?? 0);
    final d180 = fmt2(payments['revenueLast180Days'] ?? 0);
    final d365 = fmt2(payments['revenueLast365Days'] ?? 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title — Resumen',
                    style: TextStyle(
                        fontSize: 20.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 12.h),
                _rowItem('Total', '€$total'),
                _rowItem('Últimos 30 días', '€$d30'),
                _rowItem('Últimos 6 meses', '€$d180'),
                _rowItem('Últimos 12 meses', '€$d365'),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBookingsBreakdown(
      BuildContext context, Map bookings, String title) {
    final total = bookings['total']?.toString() ?? '0';
    final d30 = bookings['last30Days']?.toString() ?? '0';
    final d180 = bookings['last180Days']?.toString() ?? '0';
    final d365 = bookings['last365Days']?.toString() ?? '0';
    final byStatus =
        (bookings['byStatus'] as Map?)?.cast<String, dynamic>() ?? const {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title — Resumen',
                    style: TextStyle(
                        fontSize: 20.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 12.h),
                _rowItem('Total', total),
                _rowItem('Últimos 30 días', d30),
                _rowItem('Últimos 6 meses', d180),
                _rowItem('Últimos 12 meses', d365),
                SizedBox(height: 12.h),
                if (byStatus.isNotEmpty) ...[
                  Text('Por estado',
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8.h),
                  ...byStatus.entries.map(
                      (e) => _rowItem(_statusLabel(e.key), e.value.toString())),
                ],
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'PENDING':
        return 'Pendiente';
      case 'CONFIRMED':
        return 'Confirmada';
      case 'IN_PROGRESS':
        return 'En curso';
      case 'COMPLETED':
        return 'Completada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'REFUNDED':
        return 'Reembolsada';
      default:
        return key;
    }
  }

  Widget _rowItem(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // --- Revenue daily tile helper ---
  Widget _revenueDayTile(BuildContext context, Map m, bool first) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(left: first ? 0 : 0, right: 8.w),
      width: 84.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.grey800 : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color:
              (isDark ? AppColors.grey600 : AppColors.grey300).withOpacity(0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: () => _openDayRevenue(context, m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: _dayTooltip(m),
              child: Text((m['date'] as String).substring(5),
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)),
            ),
            SizedBox(height: 6.h),
            Text('€${(m['amount'] as num).toStringAsFixed(0)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // Contenedor completo de la serie de ingresos con sparkline, fades y flechas
  Widget _revenueSeries(BuildContext context, List<Map> series,
      {required Color sparkColor}) {
    final amounts = series.map((m) => (m['amount'] as num).toDouble()).toList();
    return SizedBox(
      height: 154.h,
      child: Stack(
        children: [
          // Sparkline animated
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 40.h,
            child: AnimatedBuilder(
              animation: _sparkCtl,
              builder: (_, __) => _Sparkline(
                amounts: amounts,
                color: sparkColor,
                progress: _sparkProgress,
              ),
            ),
          ),
          // Horizontal list
          Positioned(
            top: 48.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                },
                scrollbars: false,
              ),
              child: ListView.builder(
                controller: _revScroll,
                scrollDirection: Axis.horizontal,
                itemCount: series.length,
                padding: EdgeInsets.only(right: 16.w),
                itemBuilder: (context, index) {
                  final m = series[index];
                  return _revenueDayTile(context, m, index == 0);
                },
              ),
            ),
          ),
          // Animated fade gradients mejorados
          Positioned.fill(
            top: 48.h,
            child: IgnorePointer(
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: (_controlsVisible && _canScrollLeft) ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      offset: (_controlsVisible && _canScrollLeft)
                          ? Offset.zero
                          : const Offset(-0.08, 0),
                      child: Container(
                        width: 42.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              _edgeGradientColor(context, left: true)
                                  .withOpacity(0.16),
                              _edgeGradientColor(context, left: true)
                                  .withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  AnimatedOpacity(
                    opacity: (_controlsVisible && _canScrollRight) ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      offset: (_controlsVisible && _canScrollRight)
                          ? Offset.zero
                          : const Offset(0.08, 0),
                      child: Container(
                        width: 42.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              _edgeGradientColor(context, left: false)
                                  .withOpacity(0.16),
                              _edgeGradientColor(context, left: false)
                                  .withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Animated arrows mejorados
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            left: (_controlsVisible && _canScrollLeft) ? 4.w : -40.w,
            top: 48.h + 34.h,
            child: AnimatedOpacity(
              opacity: (_controlsVisible && _canScrollLeft) ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 260),
                scale: (_controlsVisible && _canScrollLeft) ? 1 : 0.85,
                child: _arrowButton(Icons.chevron_left, () => _onArrow(-1)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            right: (_controlsVisible && _canScrollRight) ? 4.w : -40.w,
            top: 48.h + 34.h,
            child: AnimatedOpacity(
              opacity: (_controlsVisible && _canScrollRight) ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 260),
                scale: (_controlsVisible && _canScrollRight) ? 1 : 0.85,
                child: _arrowButton(Icons.chevron_right, () => _onArrow(1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _edgeGradientColor(BuildContext context, {required bool left}) {
    if (!_revScroll.hasClients) return Colors.black12;
    final max = _revScroll.position.maxScrollExtent;
    final off = _revScroll.offset.clamp(0, max);
    double remainingFraction;
    if (max <= 0) {
      remainingFraction = 0;
    } else {
      remainingFraction = left ? (off / max) : ((max - off) / max);
    }
    remainingFraction = remainingFraction.clamp(0, 1);
    // Para rangos cortos (7d) usa fade neutro
    if (_lastRangeDays == 7) {
      return Theme.of(context).cardColor;
    }
    // Verde (mucho), amarillo (medio), rojo (poco)
    const Color green = Colors.green;
    const Color yellow = Colors.yellow;
    const Color red = Colors.red;
    if (remainingFraction < 0.5) {
      final t = remainingFraction * 2.0; // 0..1
      return Color.lerp(red, yellow, t) ?? yellow;
    } else {
      final t = (remainingFraction - 0.5) * 2.0; // 0..1
      return Color.lerp(yellow, green, t) ?? green;
    }
  }

  void _maybeAnimateSeries(List<Map> series, {bool force = false}) {
    if (series.isEmpty) return;
    int hash = 17;
    for (final m in series) {
      hash = hash * 31 + (m['amount'] as num).round();
    }
    if (force || hash != _lastSeriesHash) {
      _lastSeriesHash = hash;
      _sparkCtl.forward(from: 0);
    }
  }

  void _exportCsv(BuildContext context, List<Map> series, int rangeDays) async {
    double total = 0;
    for (final m in series) {
      total += (m['amount'] as num).toDouble();
    }
    final avg = series.isNotEmpty ? total / rangeDays : 0.0;
    double variationPct = 0.0;
    if (series.length > 1) {
      final first = (series.first['amount'] as num).toDouble();
      final last = (series.last['amount'] as num).toDouble();
      if (first != 0) variationPct = ((last - first) / first) * 100.0;
    }
    final buffer = StringBuffer();
    buffer.writeln('range_days,total,average_per_day,variation_pct');
    buffer.writeln(
        '$rangeDays,${total.toStringAsFixed(2)},${avg.toStringAsFixed(2)},${variationPct.toStringAsFixed(1)}');
    buffer.writeln();
    buffer.writeln('date,amount');
    for (final m in series) {
      buffer.writeln('${m['date']},${m['amount']}');
    }
    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Icon(icon, size: 18.sp, color: Colors.white),
          ),
        ),
      );

  void _onArrow(int direction) {
    _bumpControlsVisibility();
    _scrollBy(direction);
  }

  void _scrollBy(int direction) {
    if (!_revScroll.hasClients) return;
    final tileWidth = 84.w + 8.w; // tile + gap
    final target = (_revScroll.offset + direction * tileWidth * 3)
        .clamp(0, _revScroll.position.maxScrollExtent);
    _revScroll.animateTo(target.toDouble(),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _dayTooltip(Map m) {
    final date = m['date'];
    final amount = (m['amount'] as num).toStringAsFixed(2);
    return '$date → €$amount';
  }

  void _openDayRevenue(BuildContext context, Map m) {
    final date = m['date'];
    final amount = (m['amount'] as num).toStringAsFixed(2);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalle ingresos día',
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 12.h),
              _rowItem('Fecha', date.toString()),
              _rowItem('Monto', '€$amount'),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }
}

// Sparkline con animación progresiva
class _Sparkline extends StatelessWidget {
  final List<double> amounts;
  final Color color;
  final double progress; // 0..1
  const _Sparkline(
      {required this.amounts, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          _SparklinePainter(amounts: amounts, color: color, progress: progress),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> amounts;
  final Color color;
  final double progress; // 0..1
  _SparklinePainter(
      {required this.amounts, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (amounts.isEmpty) return;
    final maxV = amounts.reduce(math.max);
    final minV = amounts.reduce(math.min);
    final span = (maxV - minV).abs() < 0.0001 ? 1 : (maxV - minV);
    final path = Path();
    final denom = (amounts.length - 1);
    if (denom == 0) {
      final y = size.height - ((amounts.first - minV) / span) * size.height;
      path.moveTo(size.width / 2, y);
    } else {
      // Construcción de puntos normalizados
      final points = <Offset>[];
      for (int i = 0; i < amounts.length; i++) {
        final x = size.width * (i / denom);
        final norm = (amounts[i] - minV) / span;
        final y = size.height - norm * size.height;
        points.add(Offset(x, y));
      }

      // Número de segmentos y hasta dónde dibujar según progress
      final totalSeg = denom.toDouble();
      final drawSeg = (progress.clamp(0, 1) * totalSeg);
      final lastFullIndex = drawSeg.floor();

      // Suavizado con curvas cuadráticas usando puntos medios para los tramos completos
      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);
      }
      for (int i = 1; i <= lastFullIndex && i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }

      // Tramo parcial hacia el siguiente punto (sin suavizado complejo)
      if (lastFullIndex < denom) {
        final nextIndex = lastFullIndex + 1;
        if (nextIndex < points.length) {
          final remain = drawSeg - lastFullIndex; // 0..1 fracción
          final p0 = points[lastFullIndex];
          final p1 = points[nextIndex];
          final xInterp = p0.dx + (p1.dx - p0.dx) * remain;
          final yInterp = p0.dy + (p1.dy - p0.dy) * remain;
          path.lineTo(xInterp, yInterp);
        }
      } else if (points.length >= 2) {
        // Cerrar hasta el último punto para asegurar continuidad cuando progress==1
        final pLastMinus = points[points.length - 2];
        final pLast = points.last;
        path.quadraticBezierTo(
            pLastMinus.dx, pLastMinus.dy, pLast.dx, pLast.dy);
      }
    }
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.amounts != amounts || old.color != color || old.progress != progress;
}
