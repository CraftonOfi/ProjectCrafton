import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  // Colores principales
  static const Color primary = Color(0xFF2563EB); // Azul profesional
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Colores secundarios
  static const Color secondary = Color(0xFF10B981); // Verde para confirmaciones
  static const Color accent = Color(0xFFF59E0B); // Amarillo para alertas

  // Colores de estado
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Grises
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Fondo y superficies
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);

  // Texto
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
}

class ThemeConfig {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      fontFamily: 'Inter',

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.surface,
        shadowColor: AppColors.grey200,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          textStyle: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        hintStyle: TextStyle(
          color: AppColors.grey500,
          fontSize: 16.sp,
          fontFamily: 'Inter',
        ),
      ),

      // Text Themes
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        displayMedium: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        displaySmall: TextStyle(
          fontSize: 24.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        headlineLarge: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        headlineMedium: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        headlineSmall: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        titleLarge: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        titleMedium: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        titleSmall: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
        ),
        bodyLarge: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        bodyMedium: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        bodySmall: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
        ),
        labelLarge: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        labelMedium: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
        ),
        labelSmall: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final lt = lightTheme;
    return lt.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
        background: AppColors.backgroundDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // AppBar Theme para modo oscuro
      appBarTheme: lt.appBarTheme.copyWith(
        titleTextStyle: lt.appBarTheme.titleTextStyle?.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
        ),
      ),

      // Card Theme para modo oscuro
      cardTheme: lt.cardTheme.copyWith(
        color: AppColors.surfaceDark,
        shadowColor: Colors.black26,
      ),

      // Text Theme para modo oscuro (colores legibles en fondos oscuros)
      textTheme: lt.textTheme.copyWith(
        displayLarge: lt.textTheme.displayLarge
            ?.copyWith(color: AppColors.textPrimaryDark),
        displayMedium: lt.textTheme.displayMedium
            ?.copyWith(color: AppColors.textPrimaryDark),
        displaySmall: lt.textTheme.displaySmall
            ?.copyWith(color: AppColors.textPrimaryDark),
        headlineLarge: lt.textTheme.headlineLarge
            ?.copyWith(color: AppColors.textPrimaryDark),
        headlineMedium: lt.textTheme.headlineMedium
            ?.copyWith(color: AppColors.textPrimaryDark),
        headlineSmall: lt.textTheme.headlineSmall
            ?.copyWith(color: AppColors.textPrimaryDark),
        titleLarge:
            lt.textTheme.titleLarge?.copyWith(color: AppColors.textPrimaryDark),
        titleMedium: lt.textTheme.titleMedium
            ?.copyWith(color: AppColors.textPrimaryDark),
        titleSmall: lt.textTheme.titleSmall
            ?.copyWith(color: AppColors.textSecondaryDark),
        bodyLarge:
            lt.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimaryDark),
        bodyMedium:
            lt.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimaryDark),
        bodySmall: lt.textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondaryDark),
        labelLarge:
            lt.textTheme.labelLarge?.copyWith(color: AppColors.textPrimaryDark),
        labelMedium: lt.textTheme.labelMedium
            ?.copyWith(color: AppColors.textSecondaryDark),
        labelSmall: lt.textTheme.labelSmall
            ?.copyWith(color: AppColors.textSecondaryDark),
      ),
    );
  }
}
