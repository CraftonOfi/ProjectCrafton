import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../config/theme_config.dart';

class CustomTextField extends StatelessWidget {
  final String name;
  final String? label;
  final String? hintText;
  final String? initialValue;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String? Function(String?)>? validators;
  final Function(String?)? onChanged;
  final Function(String?)? onSubmitted;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final bool readOnly;

  const CustomTextField({
    super.key,
    required this.name,
    this.label,
    this.hintText,
    this.initialValue,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validators,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.controller,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 8.h),
        ],
        FormBuilderTextField(
          name: name,
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          controller: controller,
          readOnly: readOnly,
          validator: validators != null
              ? (value) {
                  for (final validator in validators!) {
                    final error = validator.call(value);
                    if (error != null) return error;
                  }
                  return null;
                }
              : null,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 16.sp,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: hintText ?? label,
            hintStyle: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.grey500,
              fontSize: 16.sp,
              fontFamily: 'Inter',
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.grey500,
                    size: 20.sp,
                  )
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? (enabled ? AppColors.surfaceDark : AppColors.grey800)
                : (enabled ? AppColors.grey50 : AppColors.grey100),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                  color: isDark ? AppColors.grey700 : AppColors.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                  color: isDark ? AppColors.grey700 : AppColors.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                  color: isDark ? AppColors.grey700 : AppColors.grey200),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            counterText: maxLength != null ? null : '',
            errorStyle: TextStyle(
              fontSize: 12.sp,
              color: AppColors.error,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// Variante para búsqueda
class SearchTextField extends StatelessWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autofocus;

  const SearchTextField({
    super.key,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.grey50,
        borderRadius: BorderRadius.circular(12.r),
        border:
            Border.all(color: isDark ? AppColors.grey700 : AppColors.grey300),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 16.sp,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        decoration: InputDecoration(
          hintText: hintText ?? 'Buscar...',
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.grey500,
            fontSize: 16.sp,
            fontFamily: 'Inter',
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? AppColors.textSecondaryDark : AppColors.grey500,
            size: 20.sp,
          ),
          suffixIcon: controller?.text.isNotEmpty == true
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.grey500,
                    size: 20.sp,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
        ),
      ),
    );
  }
}

// Campo de texto para áreas grandes
class CustomTextArea extends StatelessWidget {
  final String name;
  final String? label;
  final String? hintText;
  final String? initialValue;
  final List<String? Function(String?)>? validators;
  final Function(String?)? onChanged;
  final int maxLines;
  final int? maxLength;

  const CustomTextArea({
    super.key,
    required this.name,
    this.label,
    this.hintText,
    this.initialValue,
    this.validators,
    this.onChanged,
    this.maxLines = 5,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      name: name,
      label: label,
      hintText: hintText,
      initialValue: initialValue,
      validators: validators,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }
}
