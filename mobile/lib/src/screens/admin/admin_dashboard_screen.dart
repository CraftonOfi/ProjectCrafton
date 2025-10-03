import '../../models/resource_model.dart';
import '../../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/custom_button.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar estadísticas iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resourcesProvider.notifier).loadResources(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final resourceStats = ref.watch(resourceStatsProvider);
    final resourcesState = ref.watch(resourcesProvider);

    // Verificar permisos de administrador usando enum UserRole
    // user?.role es de tipo UserRole (ver user_model.dart) => usar extensión isAdmin
    final isAdmin = user?.role.isAdmin ?? false;
    if (!isAdmin) {
      return _buildUnauthorizedView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(resourcesProvider.notifier)
              .loadResources(refresh: true);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de bienvenida
              _buildWelcomeHeader(user?.name ?? 'Administrador'),

              SizedBox(height: 24.h),

              // Estadísticas generales
              _buildStatsCards(resourceStats),

              SizedBox(height: 24.h),

              // Acciones rápidas
              _buildQuickActions(context),

              SizedBox(height: 24.h),

              // Recursos recientes
              _buildRecentResources(resourcesState),

              SizedBox(height: 24.h),

              // Acciones administrativas
              _buildAdminActions(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateResourceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Crear Recurso'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Denegado'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64.sp,
                color: AppColors.error,
              ),
              SizedBox(height: 16.h),
              Text(
                'Sin Permisos de Administrador',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'No tienes permisos para acceder al panel de administración.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              CustomButton(
                text: 'Volver al Inicio',
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String userName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent,
            AppColors.accent.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 32.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel de Administración',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Bienvenido, $userName',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Gestiona recursos, supervisa reservas y mantén el sistema funcionando perfectamente.',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, int> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas Generales',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Recursos',
              stats['total'].toString(),
              Icons.inventory_outlined,
              AppColors.primary,
            ),
            _buildStatCard(
              'Espacios',
              stats['storage'].toString(),
              Icons.warehouse_outlined,
              AppColors.info,
            ),
            _buildStatCard(
              'Máquinas Láser',
              stats['laser'].toString(),
              Icons.precision_manufacturing_outlined,
              AppColors.secondary,
            ),
            _buildStatCard(
              'Activos',
              stats['active'].toString(),
              Icons.check_circle_outline,
              AppColors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border:
            Border.all(color: isDark ? AppColors.grey700 : AppColors.grey200),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.grey200.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Crear Espacio',
                'Agregar nuevo espacio de almacén',
                Icons.add_business,
                AppColors.primary,
                () => _showCreateResourceDialog(context, isStorage: true),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                'Crear Máquina',
                'Agregar máquina de corte láser',
                Icons.add_circle_outline,
                AppColors.secondary,
                () => _showCreateResourceDialog(context, isStorage: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentResources(ResourcesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recursos Recientes',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navegar a gestión completa de recursos
                context.push('/admin/resources');
              },
              child: Text(
                'Ver todos',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (state.isLoading && state.resources.isEmpty) ...[
          const Center(
            child: CircularProgressIndicator(),
          ),
        ] else if (state.resources.isEmpty) ...[
          _buildEmptyResourcesCard(),
        ] else ...[
          ...state.resources
              .take(3)
              .map((resource) => _buildResourcePreviewCard(resource)),
        ],
      ],
    );
  }

  Widget _buildEmptyResourcesCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48.sp,
            color: AppColors.grey400,
          ),
          SizedBox(height: 12.h),
          Text(
            'No hay recursos creados',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Crea tu primer recurso para comenzar',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 16.h),
          CustomButton(
            text: 'Crear Primer Recurso',
            onPressed: () => _showCreateResourceDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcePreviewCard(resource) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border:
            Border.all(color: isDark ? AppColors.grey700 : AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: (isDark
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.inventory_outlined,
              color: AppColors.primary,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  resource.formattedPrice,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDark ? AppColors.grey500 : AppColors.grey400,
            size: 20.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administración',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        _buildAdminActionTile(
          'Gestionar Recursos',
          'Ver, editar y eliminar recursos',
          Icons.settings,
          () {
            context.push('/admin/resources');
          },
        ),
        _buildAdminActionTile(
          'Ver Reservas',
          'Supervisar todas las reservas',
          Icons.calendar_today,
          () {
            context.push('/admin/bookings');
          },
        ),
        _buildAdminActionTile(
          'Reportes',
          'Estadísticas y análisis',
          Icons.analytics,
          () {
            context.push('/admin/reports');
          },
        ),
      ],
    );
  }

  Widget _buildAdminActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: isDark ? AppColors.grey800 : AppColors.grey100,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          size: 20.sp,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.sp,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppColors.grey500 : AppColors.grey400,
        size: 20.sp,
      ),
      onTap: onTap,
    );
  }

  void _showCreateResourceDialog(BuildContext context, {bool? isStorage}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateResourceBottomSheet(
        initialType: isStorage == true
            ? ResourceType.storageSpace
            : isStorage == false
                ? ResourceType.laserMachine
                : null,
      ),
    );
  }
}

// Bottom Sheet para crear recursos
class CreateResourceBottomSheet extends ConsumerStatefulWidget {
  final ResourceType? initialType;

  const CreateResourceBottomSheet({
    super.key,
    this.initialType,
  });

  @override
  ConsumerState<CreateResourceBottomSheet> createState() =>
      _CreateResourceBottomSheetState();
}

class _CreateResourceBottomSheetState
    extends ConsumerState<CreateResourceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  ResourceType _selectedType = ResourceType.storageSpace;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Título
          Text(
            'Crear Nuevo Recurso',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 20.h),

          // Formulario
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Tipo de recurso
                    _buildTypeSelector(),

                    SizedBox(height: 16.h),

                    // Nombre
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del recurso',
                        hintText: 'Ej: Almacén Norte - Planta 1',
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Describe las características del recurso',
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'La descripción es requerida';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Precio por hora
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio por hora (€)',
                        hintText: '25.00',
                        prefixText: '€ ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'El precio es requerido';
                        }
                        final price = double.tryParse(value!);
                        if (price == null || price <= 0) {
                          return 'Ingresa un precio válido';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Ubicación
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación',
                        hintText: 'Barcelona, Madrid, Valencia...',
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Capacidad
                    TextFormField(
                      controller: _capacityController,
                      decoration: InputDecoration(
                        labelText: _selectedType == ResourceType.storageSpace
                            ? 'Capacidad (m²)'
                            : 'Especificaciones técnicas',
                        hintText: _selectedType == ResourceType.storageSpace
                            ? '50 m²'
                            : 'Hasta 5mm acero, 200x300mm área',
                      ),
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateResource,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear Recurso'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de recurso',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedType = ResourceType.storageSpace),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _selectedType == ResourceType.storageSpace
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: _selectedType == ResourceType.storageSpace
                          ? AppColors.primary
                          : AppColors.grey300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warehouse_outlined,
                        color: _selectedType == ResourceType.storageSpace
                            ? AppColors.primary
                            : AppColors.grey500,
                        size: 24.sp,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Espacio de Almacén',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: _selectedType == ResourceType.storageSpace
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedType = ResourceType.laserMachine),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _selectedType == ResourceType.laserMachine
                        ? AppColors.secondary.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: _selectedType == ResourceType.laserMachine
                          ? AppColors.secondary
                          : AppColors.grey300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.precision_manufacturing_outlined,
                        color: _selectedType == ResourceType.laserMachine
                            ? AppColors.secondary
                            : AppColors.grey500,
                        size: 24.sp,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Máquina Láser',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: _selectedType == ResourceType.laserMachine
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleCreateResource() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(resourcesProvider.notifier).createResource(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _selectedType,
            pricePerHour: double.parse(_priceController.text.trim()),
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            capacity: _capacityController.text.trim().isEmpty
                ? null
                : _capacityController.text.trim(),
          );

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurso creado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error creando el recurso'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
