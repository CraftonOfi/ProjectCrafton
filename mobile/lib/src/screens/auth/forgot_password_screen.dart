import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../config/theme_config.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40.h),
              
              // Header
              _buildHeader(),
              
              SizedBox(height: 40.h),
              
              // Content based on state
              if (!_emailSent) ...[
                _buildRequestForm(),
              ] else ...[
                _buildSuccessMessage(),
              ],
              
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset_outlined,
            size: 40.sp,
            color: AppColors.primary,
          ),
        ),
        
        SizedBox(height: 24.h),
        
        Text(
          _emailSent ? '¡Email Enviado!' : '¿Olvidaste tu contraseña?',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        
        SizedBox(height: 8.h),
        
        Text(
          _emailSent 
            ? 'Hemos enviado las instrucciones para restablecer tu contraseña a tu email.'
            : 'No te preocupes, te ayudaremos a recuperar el acceso a tu cuenta.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestForm() {
    return FormBuilder(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresa tu dirección de email y te enviaremos un enlace para restablecer tu contraseña.',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          
          SizedBox(height: 32.h),
          
          // Email
          CustomTextField(
            name: 'email',
            label: 'Correo electrónico',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validators: [
              FormBuilderValidators.required(errorText: 'El email es requerido'),
              FormBuilderValidators.email(errorText: 'Ingresa un email válido'),
            ],
            onSubmitted: (_) => _handleSendResetEmail(),
          ),
          
          SizedBox(height: 32.h),
          
          // Botón de enviar
          CustomButton(
            text: 'Enviar Enlace de Recuperación',
            onPressed: _isLoading ? null : _handleSendResetEmail,
            isLoading: _isLoading,
            width: double.infinity,
          ),
          
          SizedBox(height: 24.h),
          
          // Enlace para volver a login
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Volver al inicio de sesión',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        // Icono de éxito
        Container(
          width: 100.w,
          height: 100.w,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 50.sp,
            color: AppColors.success,
          ),
        ),
        
        SizedBox(height: 24.h),
        
        Text(
          'Revisa tu bandeja de entrada',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        
        SizedBox(height: 12.h),
        
        Text(
           'Si no encuentras el email en tu bandeja de entrada, revisa la carpeta de spam.',
           textAlign: TextAlign.center,
           style: TextStyle(
             fontSize: 14.sp,
             color: AppColors.textSecondary,
             height: 1.5,
           ),
         ),
        
        SizedBox(height: 32.h),
        
        // Botón para reenviar
        CustomOutlineButton(
          text: 'Reenviar Email',
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
          },
          width: double.infinity,
        ),
        
        SizedBox(height: 16.h),
        
        // Botón para volver a login
        CustomButton(
          text: 'Volver al Inicio de Sesión',
          onPressed: () => context.go('/login'),
          width: double.infinity,
        ),
      ],
    );
  }

  Future<void> _handleSendResetEmail() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final formData = _formKey.currentState!.value;
      final email = formData['email'] as String;

      // TODO: Implementar llamada real a la API cuando esté disponible
      // Por ahora, simular el envío del email
      await Future.delayed(const Duration(seconds: 2));

      // Simulamos que el email se envió exitosamente
      setState(() {
        _emailSent = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email de recuperación enviado a $email'),
          backgroundColor: AppColors.success,
        ),
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando email: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}