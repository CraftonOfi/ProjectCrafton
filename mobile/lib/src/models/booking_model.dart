import 'package:json_annotation/json_annotation.dart';
// Mantener este modelo libre de dependencias de UI. (Se movieron helpers de color a util separado.)
import 'user_model.dart';
import 'resource_model.dart';
import 'payment_model.dart';

part 'booking_model.g.dart';

@JsonSerializable()
class BookingModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double totalHours;
  final double totalPrice;
  final BookingStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String resourceId;
  final UserModel? user;
  final ResourceModel? resource;
  final List<PaymentModel>? payments;

  const BookingModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    required this.totalPrice,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.resourceId,
    this.user,
    this.resource,
    this.payments,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);
  Map<String, dynamic> toJson() => _$BookingModelToJson(this);

  BookingModel copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? totalHours,
    double? totalPrice,
    BookingStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? resourceId,
    UserModel? user,
    ResourceModel? resource,
    List<PaymentModel>? payments,
  }) {
    return BookingModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalHours: totalHours ?? this.totalHours,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      resourceId: resourceId ?? this.resourceId,
      user: user ?? this.user,
      resource: resource ?? this.resource,
      payments: payments ?? this.payments,
    );
  }

  // Getters útiles
  String get formattedPrice => '€${totalPrice.toStringAsFixed(2)}';

  String get formattedDuration {
    if (totalHours < 24) {
      return '${totalHours.toStringAsFixed(1)} horas';
    } else {
      final days = (totalHours / 24).floor();
      final remainingHours = totalHours % 24;
      if (remainingHours == 0) {
        return '$days ${days == 1 ? 'día' : 'días'}';
      } else {
        return '$days ${days == 1 ? 'día' : 'días'} y ${remainingHours.toStringAsFixed(1)} horas';
      }
    }
  }

  String get statusDisplayName => status.displayName;

  bool get isPaid =>
      payments?.any((p) => p.status == PaymentStatus.completed) ?? false;

  bool get canBeCancelled =>
      status == BookingStatus.pending || status == BookingStatus.confirmed;

  bool get isActive =>
      status == BookingStatus.inProgress ||
      (status == BookingStatus.confirmed && DateTime.now().isAfter(startTime));

  bool get isUpcoming =>
      status == BookingStatus.confirmed && DateTime.now().isBefore(startTime);

  Duration get timeUntilStart => startTime.difference(DateTime.now());

  Duration get timeUntilEnd => endTime.difference(DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BookingModel{id: $id, status: $status, startTime: $startTime, totalPrice: $totalPrice}';
  }
}

@JsonEnum()
enum BookingStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('REFUNDED')
  refunded,
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pendiente';
      case BookingStatus.confirmed:
        return 'Confirmada';
      case BookingStatus.inProgress:
        return 'En Progreso';
      case BookingStatus.completed:
        return 'Completada';
      case BookingStatus.cancelled:
        return 'Cancelada';
      case BookingStatus.refunded:
        return 'Reembolsada';
    }
  }

  String get color {
    switch (this) {
      case BookingStatus.pending:
        return 'orange';
      case BookingStatus.confirmed:
        return 'blue';
      case BookingStatus.inProgress:
        return 'green';
      case BookingStatus.completed:
        return 'grey';
      case BookingStatus.cancelled:
        return 'red';
      case BookingStatus.refunded:
        return 'purple';
    }
  }

  bool get isCompleted =>
      this == BookingStatus.completed ||
      this == BookingStatus.cancelled ||
      this == BookingStatus.refunded;

  // (UI helpers removidos a booking_status_ui.dart)
}
