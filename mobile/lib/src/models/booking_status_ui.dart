import 'package:flutter/material.dart';
import 'booking_model.dart';
import '../config/theme_config.dart';

Color bookingStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return AppColors.accent; // amber
    case BookingStatus.confirmed:
      return AppColors.info; // blue
    case BookingStatus.inProgress:
      return AppColors.success; // green
    case BookingStatus.completed:
      return AppColors.grey500; // softer grey
    case BookingStatus.cancelled:
      return AppColors.error; // red
    case BookingStatus.refunded:
      return AppColors.secondary; // green teal
  }
}

Chip bookingStatusChip(BookingStatus status) {
  final base = bookingStatusColor(status);
  return Chip(
    label: Text(status.displayName),
    backgroundColor: base.withOpacity(0.15),
    labelStyle: TextStyle(
      color: _darker(base),
      fontWeight: FontWeight.w600,
    ),
    side: BorderSide(color: base.withOpacity(0.4)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

Color _darker(Color c) {
  final hsl = HSLColor.fromColor(c);
  final dark = hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0));
  return dark.toColor();
}
