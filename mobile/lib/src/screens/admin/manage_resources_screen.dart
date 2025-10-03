import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_config.dart';

class ManageResourcesScreen extends StatelessWidget {
  const ManageResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Recursos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Pantalla en Construcción',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                'Esta pantalla mostrará:\n'
                '• Lista completa de recursos\n'
                '• Opciones de editar/eliminar\n'
                '• Filtros y búsqueda\n'
                '• Estados de disponibilidad\n'
                '• Estadísticas de uso',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar creación de recurso
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Recurso'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}