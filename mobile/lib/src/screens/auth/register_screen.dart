import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../../services/api_service.dart';
import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Escuchar cambios en el estado de autenticación
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go('/home');
      }
      
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),
              
              // Header
              _buildHeader(),
              
              SizedBox(height: 32.h),
              
              // Formulario
              _buildRegisterForm(authState),
              
              SizedBox(height: 24.h),
              
              // Enlace a login
              _buildLoginLink(),
              
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
        Text(
          'Crear Nueva Cuenta',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        
        SizedBox(height: 8.h),
        
        Text(
          'Únete a nuestra comunidad y accede a espacios de almacén y máquinas de corte láser',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthState authState) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          // Nombre completo
          CustomTextField(
            name: 'name',
            label: 'Nombre completo',
            prefixIcon: Icons.person_outlined,
            textInputAction: TextInputAction.next,
            validators: [
              FormBuilderValidators.required(errorText: 'El nombre es requerido'),
              FormBuilderValidators.minLength(2, errorText: 'Mínimo 2 caracteres'),
              FormBuilderValidators.maxLength(50, errorText: 'Máximo 50 caracteres'),
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // Email
          CustomTextField(
            name: 'email',
            label: 'Correo electrónico',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validators: [
              FormBuilderValidators.required(errorText: 'El email es requerido'),
              FormBuilderValidators.email(errorText: 'Ingresa un email válido'),
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // Teléfono (opcional)
          CustomTextField(
            name: 'phone',
            label: 'Teléfono (opcional)',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validators: [
                FormBuilderValidators.match(
                  RegExp(r'^(\+34|0034|34)?[6-9][0-9]{8}$'),
                  errorText: 'Ingresa un número de teléfono español válido',
                ),
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // Contraseña
          CustomTextField(
            name: 'password',
            label: 'Contraseña',
            prefixIcon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.grey500,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validators: [
              FormBuilderValidators.required(errorText: 'La contraseña es requerida'),
              FormBuilderValidators.minLength(6, errorText: 'Mínimo 6 caracteres'),
              (value) {
                if (value == null || value.isEmpty) return null;
                
                // Validar que tenga al menos una letra y un número
                if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                  return 'Debe contener al menos una letra y un número';
                }
                return null;
              },
            ],
          ),
          
          SizedBox(height: 20.h),
          
          // Confirmar contraseña
          CustomTextField(
            name: 'confirmPassword',
            label: 'Confirmar contraseña',
            prefixIcon: Icons.lock_outlined,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.grey500,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validators: [
              FormBuilderValidators.required(errorText: 'Confirma tu contraseña'),
              (value) {
                final password = _formKey.currentState?.fields['password']?.value;
                if (value != password) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ],
            onSubmitted: (_) => _handleRegister(),
          ),
          
          SizedBox(height: 24.h),
          
          // Términos y condiciones
          FormBuilderCheckbox(
            name: 'acceptTerms',
            initialValue: false,
            validator: FormBuilderValidators.required(
              errorText: 'Debes aceptar los términos y condiciones',
            ),
            title: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Acepto los '),
                  TextSpan(
                    text: 'términos y condiciones',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(text: ' y la '),
                  TextSpan(
                    text: 'política de privacidad',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 32.h),
          
          // Botón de registro
          CustomButton(
            text: 'Crear Cuenta',
            onPressed: authState.isLoading ? null : _handleRegister,
            isLoading: authState.isLoading,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Ya tienes cuenta? ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: Text(
              'Inicia sesión',
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

  Future<void> _handleRegister() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() {
        // Si tienes un isLoading, actívalo aquí
      });
      final formData = _formKey.currentState!.value;
      final name = formData['name'] as String;
      final email = formData['email'] as String;
      final password = formData['password'] as String;
      final phoneRaw = formData['phone'];
      final phone = phoneRaw != null && phoneRaw.toString().isNotEmpty ? phoneRaw.toString() : null;

      try {
        final apiService = ApiService();
        final response = await apiService.register(
          email: email,
          password: password,
          name: name,
          phone: phone,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Registro exitoso! Bienvenido ${response['user']['name']}'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            // Si tienes un isLoading, desactívalo aquí
          });
        }
      }
    }
  }
}