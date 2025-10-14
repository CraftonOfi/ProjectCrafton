import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../config/theme_config.dart';
import '../models/resource_model.dart';
import 'resource_type_badge.dart';

/// Reusable card to display a resource with type badge, price, description,
/// location / capacity info and optional reserve action.
class ResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final VoidCallback? onTap;
  final VoidCallback? onReserve;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool showReserveButton;
  // When true, shows price per hour below the title instead of in the header
  final bool priceBelowTitle;

  const ResourceCard({
    super.key,
    required this.resource,
    this.onTap,
    this.onReserve,
    this.margin,
    this.padding,
    this.showReserveButton = true,
    this.priceBelowTitle = false,
  });

  // Shimmer/placeholder para estados de carga
  static Widget placeholder({EdgeInsets? margin}) {
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 12.h),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 120.w, height: 18.h),
              SizedBox(height: 12.h),
              _shimmerBox(width: 200.w, height: 16.h),
              SizedBox(height: 6.h),
              _shimmerBox(width: double.infinity, height: 12.h),
              SizedBox(height: 6.h),
              _shimmerBox(width: 240.w, height: 12.h),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _shimmerBox(width: 100.w, height: 12.h),
                  SizedBox(width: 12.w),
                  _shimmerBox(width: 80.w, height: 12.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _shimmerBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.grey300.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 12.h),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          // Provide splash even when null action
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: padding ?? EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 12.h),
                _buildTitle(),
                if (priceBelowTitle) ...[
                  SizedBox(height: 6.h),
                  _buildPriceBelow(),
                ],
                SizedBox(height: 6.h),
                _buildDescription(),
                SizedBox(height: 12.h),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResourceTypeBadge(type: resource.type),
            if (priceBelowTitle) ...[
              SizedBox(width: 8.w),
              _buildStatusChip(resource.isActive),
            ],
          ],
        ),
        if (!priceBelowTitle)
          Text(
            resource.formattedPrice,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Builder(builder: (context) {
      final isDark =
          Theme.of(context).colorScheme.brightness == Brightness.dark;
      return Text(
        resource.name,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    });
  }

  Widget _buildStatusChip(bool isActive) {
    final base = isActive ? AppColors.success : AppColors.grey500;
    final label = isActive ? 'Activo' : 'Inactivo';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: base.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: base.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: base,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: base,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Builder(builder: (context) {
      final isDark =
          Theme.of(context).colorScheme.brightness == Brightness.dark;
      return Text(
        resource.description,
        style: TextStyle(
          fontSize: 14.sp,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    });
  }

  Widget _buildPriceBelow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(
            resource.formattedPrice,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final hasLoc = resource.hasLocation;
    final hasCap = resource.capacity != null;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (hasLoc) ...[
                Expanded(
                  child: _infoItem(
                    context,
                    icon: Icons.location_on_outlined,
                    text: resource.location!,
                  ),
                ),
              ],
              if (hasLoc && hasCap) SizedBox(width: 12.w),
              if (hasCap) ...[
                Expanded(
                  child: _infoItem(
                    context,
                    icon: Icons.straighten_outlined,
                    text: _abbreviateMetric(resource.capacity!),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showReserveButton)
          ElevatedButton(
            onPressed: onReserve,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Reservar',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoItem(BuildContext context,
      {required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16.sp,
          color: AppColors.grey500,
        ),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  // Abbreviate large numeric strings like 20000 -> 20k, 1250000 -> 1.25M
  String _abbreviateMetric(String raw) {
    final numeric = RegExp(r'[-+]?\d*\.?\d+').stringMatch(raw);
    if (numeric == null) return raw;
    final value = double.tryParse(numeric.replaceAll(',', '.'));
    if (value == null) return raw;
    String suffix;
    double shortened;
    if (value >= 1000000) {
      shortened = value / 1000000;
      suffix = 'M';
    } else if (value >= 1000) {
      shortened = value / 1000;
      suffix = 'k';
    } else {
      return _trimTrailingZeros(value);
    }
    final str = shortened >= 10
        ? shortened.toStringAsFixed(0)
        : shortened.toStringAsFixed(2);
    // Keep any non-numeric suffix from raw (e.g., ' m²')
    final unit = raw
        .replaceFirst(RegExp(r'^\s*' + RegExp.escape(numeric) + 's*'), '')
        .trim();
    final showUnit = unit.isNotEmpty ? ' $unit' : '';
    return '$str$suffix$showUnit';
  }

  String _trimTrailingZeros(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
