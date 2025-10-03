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

  const ResourceCard({
    super.key,
    required this.resource,
    this.onTap,
    this.onReserve,
    this.margin,
    this.padding,
    this.showReserveButton = true,
  });

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
        ResourceTypeBadge(type: resource.type),
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

  Widget _buildDescription() {
    return Text(
      resource.description,
      style: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textSecondary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (resource.hasLocation) ...[
                Icon(
                  Icons.location_on_outlined,
                  size: 16.sp,
                  color: AppColors.grey500,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    resource.location!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              if (resource.capacity != null) ...[
                Icon(
                  Icons.straighten_outlined,
                  size: 16.sp,
                  color: AppColors.grey500,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    resource.capacity!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
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
}
