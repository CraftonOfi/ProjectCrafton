import 'package:flutter/material.dart';

class AsyncStateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final Widget? empty;
  final VoidCallback? onRetry;
  final Widget child;

  const AsyncStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
    this.empty,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ha ocurrido un error',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (onRetry != null)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                )
            ],
          ),
        ),
      );
    }
    if (empty != null) {
      return empty!;
    }
    return child;
  }
}

