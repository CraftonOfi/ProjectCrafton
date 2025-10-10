import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/resource_type_badge.dart';

class ResourceDetailScreen extends ConsumerWidget {
  final String resourceId;

  const ResourceDetailScreen({
    super.key,
    required this.resourceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRes = ref.watch(resourceProvider(resourceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Recurso')),
      body: asyncRes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text('Error cargando recurso: $e'),
          ),
        ),
        data: (resource) {
          if (resource == null) {
            return const Center(child: Text('Recurso no encontrado'));
          }
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark ? AppColors.grey700 : AppColors.grey200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          ResourceTypeBadge(type: resource.type),
                          SizedBox(width: 8.w),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 16.sp, color: AppColors.primary),
                              SizedBox(width: 4.w),
                              Text(
                                resource.formattedPrice,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (resource.description.isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Text(
                          resource.description,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Info rows
                if (resource.hasLocation)
                  _infoRow(
                    context,
                    icon: Icons.location_on_outlined,
                    label: 'Ubicación',
                    value: resource.location!,
                  ),
                if (resource.capacity != null && resource.capacity!.isNotEmpty)
                  _infoRow(
                    context,
                    icon: Icons.straighten_outlined,
                    label: 'Capacidad',
                    value: _abbreviateMetric(resource.capacity!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _infoRow(BuildContext context,
    {required IconData icon, required String label, required String value}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
    margin: EdgeInsets.only(bottom: 8.h),
    decoration: BoxDecoration(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(
        color: isDark ? AppColors.grey700 : AppColors.grey200,
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18.sp, color: AppColors.grey500),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Abbreviate large numeric strings like 20000 -> 20k
String _abbreviateMetric(String raw) {
  final match = RegExp(r'[-]?\d*[\.,]?\d+').firstMatch(raw);
  if (match == null) return raw;
  final numeric = match.group(0)!;
  final value = double.tryParse(numeric.replaceAll(',', '.'));
  if (value == null) return raw;
  if (value >= 1000000) {
    final s = value / 1000000;
    return _trimZeros(s >= 10 ? s.toStringAsFixed(0) : s.toStringAsFixed(2)) +
        'M' +
        _suffix(raw, numeric);
  }
  if (value >= 1000) {
    final s = value / 1000;
    return _trimZeros(s >= 10 ? s.toStringAsFixed(0) : s.toStringAsFixed(2)) +
        'k' +
        _suffix(raw, numeric);
  }
  return _trimZeros(value.toStringAsFixed(2)) + _suffix(raw, numeric);
}

String _suffix(String raw, String numeric) {
  final unit = raw
      .replaceFirst(RegExp('^\\s*' + RegExp.escape(numeric) + '\\s*'), '')
      .trim();
  return unit.isNotEmpty ? ' ' + unit : '';
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');
  return s;
}
