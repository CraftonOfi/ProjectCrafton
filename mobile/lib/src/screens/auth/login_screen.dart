import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Escuchar cambios en el estado de autenticación (punto 1: tipo explícito)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go('/home');
      }

      if (next.error != null) {
        _showSnackBar(next.error!, AppColors.error);
      }
    });

    // Forzar tema claro en login independientemente del tema del sistema
    return Theme(
      data: ThemeConfig.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 60.h),
                // Logo/Header
                _buildHeader(),
                SizedBox(height: 48.h),
                // Formulario de login
                _buildLoginForm(authState),
                SizedBox(height: 24.h),
                // Enlace a registro
                _buildRegisterLink(),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Punto 2: método privado para mostrar SnackBar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo placeholder
        Container(
          width: 120.w,
          height: 120.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            Icons.business_center_outlined,
            size: 60.sp,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'Bienvenido',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Inicia sesión para acceder a tu cuenta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(AuthState authState) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          // Email
          CustomTextField(
            name: 'email',
            label: 'Correo electrónico',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validators: [
              FormBuilderValidators.required(
                  errorText: 'El email es requerido'),
              FormBuilderValidators.email(errorText: 'Ingresa un email válido'),
            ],
          ),
          SizedBox(height: 20.h),

          // Contraseña
          CustomTextField(
            name: 'password',
            label: 'Contraseña',
            prefixIcon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.grey500,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validators: [
              FormBuilderValidators.required(
                  errorText: 'La contraseña es requerida'),
              FormBuilderValidators.minLength(6,
                  errorText: 'Mínimo 6 caracteres'),
              // Punto 3: validación extra
              (value) {
                if (value == null || value.isEmpty) return null;
                if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                  return 'Debe contener al menos una letra y un número';
                }
                return null;
              },
            ],
            onSubmitted: (_) => _handleLogin(),
          ),
          SizedBox(height: 12.h),

          // Enlace "Olvidé mi contraseña"
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Botón de login
          CustomButton(
            text: 'Iniciar Sesión',
            onPressed: authState.isLoading ? null : _handleLogin,
            isLoading: authState.isLoading,
            width: double.infinity,
          ),
          SizedBox(height: 24.h),

          // Divider "o"
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppColors.grey300,
                  thickness: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'o',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppColors.grey300,
                  thickness: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Demo login (temporal) - punto 4: usar CustomOutlineButton si existe
          CustomOutlineButton(
            text: 'Entrar como Demo',
            onPressed: authState.isLoading ? null : _handleDemoLogin,
            isLoading: authState.isLoading && authState.error == null,
            icon: Icons.login_outlined,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿No tienes cuenta? ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/register'),
            child: Text(
              'Regístrate',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final formData = _formKey.currentState!.value;
      final email = formData['email'] as String;
      final password = formData['password'] as String;

      final success =
          await ref.read(authProvider.notifier).login(email, password);

      if (success) {
        _showSnackBar('¡Bienvenido! Has iniciado sesión correctamente.',
            AppColors.success);
      }
    }
  }

  Future<void> _handleDemoLogin() async {
    // Login demo sin validar formulario
    // Punto 6: usar constantes para demo
    const demoEmail = 'demo@example.com';
    const demoPassword = 'demo123';
    final success = await ref.read(authProvider.notifier).login(
          demoEmail,
          demoPassword,
        );

    if (success) {
      _showSnackBar('¡Bienvenido! Sesión demo iniciada.', AppColors.success);
    }
  }
}
