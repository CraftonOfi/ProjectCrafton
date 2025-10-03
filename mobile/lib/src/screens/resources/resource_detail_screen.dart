import 'package:flutter/material.dart';

class ResourceDetailScreen extends StatelessWidget {
  final String resourceId;

  const ResourceDetailScreen({
    super.key,
    required this.resourceId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Recurso'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Pantalla en Construcción',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Resource ID: $resourceId',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta pantalla mostrará:\n'
              '• Información detallada del recurso\n'
              '• Galería de imágenes\n'
              '• Disponibilidad y calendario\n'
              '• Botón para reservar\n'
              '• Reseñas y calificaciones',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}