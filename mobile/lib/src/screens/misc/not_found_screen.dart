import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends ConsumerWidget {
  final String attemptedPath;
  const NotFoundScreen({super.key, required this.attemptedPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('No encontrado'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64),
              const SizedBox(height: 16),
              Text(
                'Ruta no encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                attemptedPath,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Volver al Inicio'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
