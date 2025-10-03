import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../config/theme_config.dart';
import '../../models/resource_model.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart' show ApiException;

class BookingScreen extends ConsumerStatefulWidget {
  final String resourceId;

  const BookingScreen({
    super.key,
    required this.resourceId,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  // Real-time availability & validation state
  bool? _isAvailable; // null: unknown, true/false: result
  bool _checkingAvailability = false;
  String? _availabilityError;
  Timer? _availabilityDebounce;

  @override
  void dispose() {
    _notesController.dispose();
    _availabilityDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resourceAsync = ref.watch(resourceProvider(widget.resourceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hacer Reserva'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: resourceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
        data: (resource) {
          if (resource == null) {
            return _buildErrorState('Recurso no encontrado');
          }
          return _buildBookingForm(resource);
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: AppColors.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            CustomButton(
              text: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm(ResourceModel resource) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del recurso
          _buildResourceInfo(resource),

          SizedBox(height: 24.h),

          // Calendario
          _buildCalendarSection(),

          SizedBox(height: 24.h),

          // Selección de horarios
          _buildTimeSelection(),

          SizedBox(height: 24.h),

          // Resumen de la reserva
          _buildBookingSummary(resource),

          SizedBox(height: 24.h),

          // Notas adicionales
          _buildNotesSection(),

          SizedBox(height: 32.h),

          // Botón de reserva
          _buildBookingButton(resource),
        ],
      ),
    );
  }

  Widget _buildResourceInfo(ResourceModel resource) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    color: resource.type == ResourceType.storageSpace
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    resource.type == ResourceType.storageSpace
                        ? Icons.inventory_2_outlined
                        : Icons.precision_manufacturing_outlined,
                    color: resource.type == ResourceType.storageSpace
                        ? AppColors.primary
                        : AppColors.secondary,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        resource.typeDisplayName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        resource.formattedPrice,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (resource.hasLocation || resource.capacity != null) ...[
              SizedBox(height: 12.h),
              Divider(height: 1.h),
              SizedBox(height: 12.h),
              Row(
                children: [
                  if (resource.hasLocation) ...[
                    Icon(
                      Icons.location_on_outlined,
                      size: 16.sp,
                      color: AppColors.grey500,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      resource.location!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (resource.capacity != null) SizedBox(width: 16.w),
                  ],
                  if (resource.capacity != null) ...[
                    Icon(
                      Icons.straighten_outlined,
                      size: 16.sp,
                      color: AppColors.grey500,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      resource.capacity!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona una fecha',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: TableCalendar<Event>(
              // Normalizamos firstDay al inicio del día para evitar exclusiones por hora actual
              firstDay: DateTime(DateTime.now().year, DateTime.now().month,
                  DateTime.now().day),
              lastDay: DateTime.now().add(const Duration(days: 180)),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(
                  color: AppColors.textSecondary,
                ),
                disabledTextStyle: TextStyle(
                  color: AppColors.grey400,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDate, selectedDay)) {
                  setState(() {
                    _selectedDate = selectedDay;
                    // Reset time selection when date changes
                    _startTime = null;
                    _endTime = null;
                  });
                }
              },
              enabledDayPredicate: (day) {
                final today = DateTime.now();
                final dayDate = DateTime(day.year, day.month, day.day);
                final todayDate = DateTime(today.year, today.month, today.day);

                // Permitir hoy sólo si quedan al menos 30 minutos para algún inicio
                if (dayDate == todayDate) {
                  return true; // permitimos selección; validaremos hora luego
                }
                // Bloquear días pasados
                if (dayDate.isBefore(todayDate)) return false;
                // Dentro de ventana futura configurada (<= 180 días)
                return dayDate.difference(todayDate).inDays <= 180;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona horario',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildTimeSelector(
                label: 'Hora de inicio',
                time: _startTime,
                onTap: () => _selectTime(true),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildTimeSelector(
                label: 'Hora de fin',
                time: _endTime,
                onTap: () => _selectTime(false),
              ),
            ),
          ],
        ),
        // Inline real-time validation messages
        if (_startTime != null) ...[
          SizedBox(height: 8.h),
          Builder(builder: (context) {
            final start = _composeDateTime(isStart: true);
            final now = DateTime.now();
            if (start != null && !start.isAfter(now)) {
              return _inlineWarning(
                  'La hora de inicio debe ser futura', AppColors.warning);
            }
            return const SizedBox.shrink();
          }),
        ],
        if (_startTime != null && _endTime != null) ...[
          SizedBox(height: 8.h),
          if (!_isEndAfterStart())
            _inlineWarning(
                'La hora de fin debe ser posterior al inicio', AppColors.error),
        ],
        if (_startTime != null && _endTime != null) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppColors.info,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Duración: ${_calculateDuration()} horas',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Real-time availability indicator
          _buildAvailabilityIndicator(),
        ],
      ],
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.grey300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time?.format(context) ?? 'Seleccionar',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: time != null
                        ? AppColors.textPrimary
                        : AppColors.grey500,
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color: AppColors.grey500,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSummary(ResourceModel resource) {
    if (_startTime == null || _endTime == null) {
      return const SizedBox.shrink();
    }

    final duration = _calculateDuration();
    final totalPrice = duration * resource.pricePerHour;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de la reserva',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            _buildSummaryRow('Fecha', _formatDate(_selectedDate)),
            _buildSummaryRow('Horario',
                '${_startTime!.format(context)} - ${_endTime!.format(context)}'),
            _buildSummaryRow('Duración', '$duration horas'),
            _buildSummaryRow('Precio por hora', resource.formattedPrice),
            if (_checkingAvailability ||
                _isAvailable != null ||
                _availabilityError != null) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    _availabilityIcon(),
                    size: 16.sp,
                    color: _availabilityColor(),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      _availabilityText(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: _availabilityColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Divider(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '€${totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notas adicionales (opcional)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        CustomTextArea(
          name: 'notes',
          hintText: 'Añade cualquier información adicional sobre tu reserva...',
          maxLines: 4,
          maxLength: 500,
          onChanged: (v) => _notesController.text = v ?? '',
        ),
      ],
    );
  }

  Widget _buildBookingButton(ResourceModel resource) {
    final hasTimes = _startTime != null && _endTime != null;
    final validRange = hasTimes && _isEndAfterStart();
    final startFuture =
        _composeDateTime(isStart: true)?.isAfter(DateTime.now()) ?? false;
    final availableOk = _isAvailable != false; // null or true allow proceed
    final canBook = validRange && startFuture && availableOk;

    return CustomButton(
      text: _isLoading ? 'Procesando...' : 'Confirmar Reserva',
      onPressed: canBook && !_isLoading ? () => _handleBooking(resource) : null,
      isLoading: _isLoading,
      width: double.infinity,
      icon: Icons.event_available,
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
        if (isStartTime) {
          _startTime = picked;
          if (_endTime != null && toMinutes(_endTime!) <= toMinutes(picked)) {
            _endTime = null;
          }
        } else {
          if (_startTime != null &&
              toMinutes(picked) > toMinutes(_startTime!)) {
            _endTime = picked;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'La hora de fin debe ser posterior a la hora de inicio'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
        _scheduleAvailabilityCheck();
      });
    }
  }

  double _calculateDuration() {
    if (_startTime == null || _endTime == null) return 0;

    final start = _startTime!.hour + (_startTime!.minute / 60);
    final end = _endTime!.hour + (_endTime!.minute / 60);

    return end - start;
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

  Future<void> _handleBooking(ResourceModel resource) async {
    if (_startTime == null || _endTime == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear DateTime completos para inicio y fin
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      // Guardar: si el inicio no es futuro, evitar llamada y avisar claramente
      final now = DateTime.now();
      if (!startDateTime.isAfter(now)) {
        if (mounted) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La hora de inicio debe ser futura'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Si tenemos resultado reciente de disponibilidad y es falso, corta
      if (_isAvailable == false) {
        if (mounted) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horario no disponible (conflicto).'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Si no hay resultado previo, hacemos check puntual
      if (_isAvailable == null) {
        try {
          final ok =
              await ref.read(bookingsProvider.notifier).checkAvailability(
                    resourceId: widget.resourceId,
                    startTime: startDateTime,
                    endTime: endDateTime,
                  );
          if (!ok) {
            if (mounted) setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Horario no disponible (conflicto).'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
        } on ApiException catch (e) {
          if (mounted) setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }

      // Crear la reserva
      final booking = await ref.read(bookingsProvider.notifier).createBooking(
            resourceId: widget.resourceId,
            startTime: startDateTime,
            endTime: endDateTime,
            notes: _notesController.text.trim(),
          );

      if (booking != null) {
        if (!mounted) return;
        context.go('/booking-confirmation/${booking.id}');
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helpers
  DateTime? _composeDateTime({required bool isStart}) {
    final t = isStart ? _startTime : _endTime;
    if (t == null) return null;
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      t.hour,
      t.minute,
    );
  }

  bool _isEndAfterStart() {
    final s = _composeDateTime(isStart: true);
    final e = _composeDateTime(isStart: false);
    if (s == null || e == null) return false;
    return e.isAfter(s);
  }

  void _scheduleAvailabilityCheck() {
    _availabilityDebounce?.cancel();
    final s = _composeDateTime(isStart: true);
    final e = _composeDateTime(isStart: false);
    if (s == null || e == null) {
      setState(() {
        _isAvailable = null;
        _availabilityError = null;
        _checkingAvailability = false;
      });
      return;
    }
    // Validate prereqs: end > start and start in future
    if (!e.isAfter(s) || !s.isAfter(DateTime.now())) {
      setState(() {
        _isAvailable = null;
        _availabilityError = null;
        _checkingAvailability = false;
      });
      return;
    }

    setState(() {
      _checkingAvailability = true;
      _availabilityError = null;
    });

    _availabilityDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final ok = await ref.read(bookingsProvider.notifier).checkAvailability(
              resourceId: widget.resourceId,
              startTime: s,
              endTime: e,
            );
        if (!mounted) return;
        setState(() {
          _isAvailable = ok;
          _checkingAvailability = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _isAvailable = null;
          _checkingAvailability = false;
          _availabilityError = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isAvailable = null;
          _checkingAvailability = false;
          _availabilityError = 'No se pudo verificar disponibilidad';
        });
      }
    });
  }

  Widget _inlineWarning(String text, Color color) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13.sp, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityIndicator() {
    if (_checkingAvailability) {
      return Row(
        children: [
          SizedBox(
            width: 16.sp,
            height: 16.sp,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8.w),
          Text(
            'Comprobando disponibilidad...',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        ],
      );
    }
    if (_availabilityError != null) {
      return _inlineWarning(_availabilityError!, AppColors.warning);
    }
    if (_isAvailable == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Icon(
          _isAvailable == true ? Icons.check_circle : Icons.cancel,
          size: 16.sp,
          color: _isAvailable == true ? AppColors.success : AppColors.error,
        ),
        SizedBox(width: 6.w),
        Text(
          _isAvailable == true ? 'Horario disponible' : 'Horario no disponible',
          style: TextStyle(
            fontSize: 13.sp,
            color: _isAvailable == true ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _availabilityIcon() {
    if (_checkingAvailability) return Icons.schedule;
    if (_availabilityError != null) return Icons.info_outline;
    if (_isAvailable == true) return Icons.check_circle;
    if (_isAvailable == false) return Icons.cancel;
    return Icons.help_outline;
  }

  Color _availabilityColor() {
    if (_checkingAvailability) return AppColors.textSecondary;
    if (_availabilityError != null) return AppColors.warning;
    if (_isAvailable == true) return AppColors.success;
    if (_isAvailable == false) return AppColors.error;
    return AppColors.textSecondary;
  }

  String _availabilityText() {
    if (_checkingAvailability) return 'Comprobando disponibilidad...';
    if (_availabilityError != null) return _availabilityError!;
    if (_isAvailable == true) return 'Horario disponible';
    if (_isAvailable == false) return 'Horario no disponible';
    return '';
  }
}

// Clase auxiliar para el calendario
class Event {
  final String title;
  const Event(this.title);
}
