import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/bookings_provider.dart';
import '../../models/booking_model.dart';
import '../../models/booking_status_ui.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  final String bookingId;

  const BookingConfirmationScreen({super.key, required this.bookingId});

  Color _statusColor(BookingStatus status, BuildContext context) =>
      bookingStatusColor(status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBooking = ref.watch(bookingProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación de Reserva')),
      body: asyncBooking.when(
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Reserva no encontrada'));
          }
          final resource = booking.resource;
          final startFormatted =
              TimeOfDay.fromDateTime(booking.startTime).format(context);
          final endFormatted =
              TimeOfDay.fromDateTime(booking.endTime).format(context);
          final dateString =
              '${booking.startTime.day.toString().padLeft(2, '0')}/${booking.startTime.month.toString().padLeft(2, '0')}/${booking.startTime.year}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 42, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Reserva creada',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Chip(
                      label: Text(booking.statusDisplayName),
                      backgroundColor: _statusColor(booking.status, context)
                          .withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: _statusColor(booking.status, context)
                                .shade700OrNull ??
                            _statusColor(booking.status, context),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                if (resource != null) ...[
                  Text(resource.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    resource.hasLocation
                        ? '${resource.location} · ${resource.typeDisplayName}'
                        : resource.typeDisplayName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Divider(height: 32),
                ],
                Text('Detalles',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow(Icons.calendar_today, 'Fecha', dateString),
                _infoRow(Icons.schedule, 'Horario',
                    '$startFormatted - $endFormatted'),
                _infoRow(
                    Icons.timelapse, 'Duración', booking.formattedDuration),
                _infoRow(Icons.payments, 'Precio', booking.formattedPrice),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _infoRow(Icons.note, 'Notas', booking.notes!),
                const SizedBox(height: 24),
                Text('Acciones',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (booking.canBeCancelled)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await ref
                              .read(bookingsProvider.notifier)
                              .cancelBooking(booking.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? 'Reserva cancelada'
                                  : 'No se pudo cancelar'),
                            ));
                          }
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar'),
                      ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navegar de forma consistente al inicio usando GoRouter
                        context.go('/home');
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Inicio'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2,
                          size: 120, color: Colors.black54),
                      const SizedBox(height: 8),
                      Text('Código de acceso (placeholder)',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

extension _ColorShadeExt on Color {
  Color? get shade700OrNull {
    // Quick util to approximate a darker shade for solid text on light chip backgrounds
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0));
    return darkened.toColor();
  }
}
