import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../models/user_model.dart';
import '../../providers/user_stats_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Navegar a edición de perfil
              // context.push('/profile/edit');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Header del perfil
            _buildProfileHeader(user),

            SizedBox(height: 24.h),

            // Información personal
            _buildPersonalInfo(context, user),

            SizedBox(height: 24.h),

            // Estadísticas del usuario
            _buildUserStats(context, ref),

            SizedBox(height: 24.h),

            // Opciones del perfil
            _buildProfileOptions(context, ref),

            SizedBox(height: 32.h),

            // Botón de logout
            _buildLogoutButton(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // Nombre
          Text(
            user.name,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          SizedBox(height: 4.h),

          // Email
          Text(
            user.email,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),

          SizedBox(height: 8.h),

          // Badge de rol
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              _safeRoleDisplayName(user.role),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeRoleDisplayName(UserRole role) {
    try {
      return role.displayName;
    } catch (_) {
      // Fallback por si la extensión no estuviera disponible en runtime
      switch (role) {
        case UserRole.client:
          return 'Cliente';
        case UserRole.admin:
          return 'Administrador';
        case UserRole.superAdmin:
          return 'Super Administrador';
      }
    }
  }

  Widget _buildPersonalInfo(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información Personal',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.brightness == Brightness.dark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  'Nombre completo',
                  user.name,
                  Icons.person_outlined,
                ),
                Divider(height: 24.h),
                _buildInfoRow(
                  context,
                  'Correo electrónico',
                  user.email,
                  Icons.email_outlined,
                ),
                Divider(height: 24.h),
                _buildInfoRow(
                  context,
                  'Teléfono',
                  user.phone ?? 'No especificado',
                  Icons.phone_outlined,
                ),
                Divider(height: 24.h),
                _buildInfoRow(
                  context,
                  'Miembro desde',
                  _formatDate(user.createdAt),
                  Icons.calendar_today_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20.sp,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).colorScheme.brightness ==
                          Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).colorScheme.brightness ==
                          Brightness.dark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserStats(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.brightness == Brightness.dark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (stats.isLoading) const LinearProgressIndicator(minHeight: 2),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Reservas Totales',
                stats.totalBookings.toString(),
                Icons.book_outlined,
                AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                context,
                'Próximas',
                stats.upcomingBookings.toString(),
                Icons.upcoming_outlined,
                AppColors.secondary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Completadas',
                stats.completedBookings.toString(),
                Icons.check_circle_outline,
                AppColors.success,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                context,
                'Horas Reservadas',
                '0h', // placeholder hasta implementar cálculo
                Icons.schedule_outlined,
                AppColors.info,
              ),
            ),
          ],
        ),
        if (stats.error != null) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.error_outline, size: 16.sp, color: AppColors.error),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  stats.error!,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.error),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(userStatsProvider.notifier).refresh(),
                child: const Text('Reintentar'),
              )
            ],
          ),
        ] else ...[
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ref.read(userStatsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
            ),
          )
        ],
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.brightness == Brightness.dark
              ? AppColors.grey700
              : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24.sp,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOptions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuración',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.brightness == Brightness.dark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Card(
          child: Column(
            children: [
              _buildOptionTile(
                context,
                'Editar Perfil',
                'Actualiza tu información personal',
                Icons.edit_outlined,
                () {
                  // TODO: Navegar a edición de perfil
                  // context.push('/profile/edit');
                },
              ),
              Divider(height: 1.h),
              _buildOptionTile(
                context,
                'Cambiar Contraseña',
                'Actualiza tu contraseña de acceso',
                Icons.lock_outlined,
                () {
                  _showChangePasswordDialog(context, ref);
                },
              ),
              Divider(height: 1.h),
              _buildOptionTile(
                context,
                'Notificaciones',
                'Configura tus preferencias de notificación',
                Icons.notifications_outlined,
                () {
                  // TODO: Implementar configuración de notificaciones
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidad en desarrollo'),
                    ),
                  );
                },
              ),
              Divider(height: 1.h),
              _buildOptionTile(
                context,
                'Ayuda y Soporte',
                'Obtén ayuda o contacta con nosotros',
                Icons.help_outline,
                () {
                  // TODO: Implementar ayuda y soporte
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidad en desarrollo'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 20.sp,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.brightness == Brightness.dark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.sp,
          color: Theme.of(context).colorScheme.brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.grey400,
        size: 20.sp,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(WidgetRef ref) {
    return CustomButton(
      text: 'Cerrar Sesión',
      onPressed: () => _showLogoutDialog(ref),
      backgroundColor: AppColors.error,
      width: double.infinity,
      icon: Icons.logout_outlined,
    );
  }

  void _showLogoutDialog(WidgetRef ref) {
    showDialog(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Ingresa tu contraseña actual';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Ingresa una nueva contraseña';
                  }
                  if (value!.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                ),
                obscureText: true,
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success =
                    await ref.read(authProvider.notifier).changePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                        );

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Contraseña actualizada exitosamente'
                          : 'Error actualizando contraseña',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
