import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/resource_model.dart';
import '../config/theme_config.dart';

class ResourceTypeBadge extends StatelessWidget {
  final ResourceType type;
  final EdgeInsetsGeometry? padding;

  const ResourceTypeBadge({super.key, required this.type, this.padding});

  @override
  Widget build(BuildContext context) {
    final isStorage = type == ResourceType.storageSpace;
    final color = isStorage ? AppColors.primary : AppColors.secondary;
    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
