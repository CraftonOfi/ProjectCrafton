import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';
import '../../models/resource_model.dart';
import '../../providers/resources_provider.dart';
import '../../providers/admin_resources_provider.dart';
import '../../widgets/resource_card.dart';
import 'admin_dashboard_screen.dart' show CreateResourceBottomSheet;

class ManageResourcesScreen extends ConsumerStatefulWidget {
  const ManageResourcesScreen({super.key});

  @override
  ConsumerState<ManageResourcesScreen> createState() =>
      _ManageResourcesScreenState();
}

class _ManageResourcesScreenState extends ConsumerState<ManageResourcesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(adminResourcesProvider.notifier)
          .load(refresh: true, status: 'active');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminResourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Recursos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref
                .read(adminResourcesProvider.notifier)
                .load(refresh: true, status: adminState.status),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Inactivos'),
            Tab(text: 'Todos'),
          ],
          onTap: (i) {
            final status = i == 0
                ? 'active'
                : i == 1
                    ? 'inactive'
                    : 'all';
            ref
                .read(adminResourcesProvider.notifier)
                .load(refresh: true, status: status);
          },
        ),
      ),
      body: adminState.isLoading && adminState.resources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildList(context, adminState.resources),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Recurso'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ResourceModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text('Aún no hay recursos, crea el primero.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(adminResourcesProvider.notifier).load(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final r = items[index];
          return Column(
            children: [
              Stack(
                children: [
                  ResourceCard(
                    resource: r,
                    onTap: () {},
                    showReserveButton: false,
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 8.h),
                    priceBelowTitle: true,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _buildMenu(context, r),
                  ),
                ],
              ),
              _buildInlineActions(context, r),
              SizedBox(height: 12.h),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInlineActions(BuildContext context, ResourceModel resource) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        TextButton.icon(
          onPressed: () async {
            final newPrice = await _askPrice(context, resource.pricePerHour);
            if (newPrice != null) {
              await ref
                  .read(resourcesProvider.notifier)
                  .updateResource(resource.id, pricePerHour: newPrice);
              await ref.read(adminResourcesProvider.notifier).load(
                  refresh: true,
                  status: ref.read(adminResourcesProvider).status);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Precio actualizado')),
              );
            }
          },
          icon: const Icon(Icons.euro),
          label: const Text('Editar precio'),
          style: TextButton.styleFrom(
            foregroundColor:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () async {
            await ref
                .read(resourcesProvider.notifier)
                .updateResource(resource.id, isActive: !resource.isActive);
            await ref.read(adminResourcesProvider.notifier).load(
                refresh: true, status: ref.read(adminResourcesProvider).status);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(resource.isActive
                      ? 'Recurso desactivado'
                      : 'Recurso activado')),
            );
          },
          icon:
              Icon(resource.isActive ? Icons.visibility_off : Icons.visibility),
          label: Text(resource.isActive ? 'Desactivar' : 'Activar'),
          style: TextButton.styleFrom(
            foregroundColor:
                resource.isActive ? AppColors.error : AppColors.success,
          ),
        ),
      ],
    );
  }

  void _showCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateResourceBottomSheet(),
    );
  }

  Widget _buildMenu(BuildContext context, ResourceModel resource) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        final notifier = ref.read(resourcesProvider.notifier);
        switch (value) {
          case 'price':
            final newPrice = await _askPrice(context, resource.pricePerHour);
            if (newPrice != null) {
              await notifier.updateResource(resource.id,
                  pricePerHour: newPrice);
              // refrescar vista admin
              await ref.read(adminResourcesProvider.notifier).load(
                  refresh: true,
                  status: ref.read(adminResourcesProvider).status);
            }
            break;
          case 'toggle':
            await notifier.updateResource(resource.id,
                isActive: !resource.isActive);
            await ref.read(adminResourcesProvider.notifier).load(
                refresh: true, status: ref.read(adminResourcesProvider).status);
            break;
          case 'delete':
            final ok = await _confirm(context, 'Eliminar recurso',
                '¿Seguro que deseas eliminar este recurso?');
            if (ok) await notifier.deleteResource(resource.id);
            await ref.read(adminResourcesProvider.notifier).load(
                refresh: true, status: ref.read(adminResourcesProvider).status);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'price',
          child: ListTile(
            leading: Icon(Icons.euro),
            title: Text('Editar precio'),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            leading: Icon(
                resource.isActive ? Icons.visibility_off : Icons.visibility),
            title: Text(resource.isActive ? 'Desactivar' : 'Activar'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.error),
            title: Text('Eliminar'),
          ),
        ),
      ],
    );
  }

  Future<double?> _askPrice(BuildContext context, double current) async {
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar precio por hora'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '€ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v != null && v >= 0) {
                Navigator.pop(context, v);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<bool> _confirm(
      BuildContext context, String title, String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
          title: Text(title,
              style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          content: Text(message,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }
}
