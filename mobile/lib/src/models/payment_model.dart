import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';
import 'booking_model.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  final String id;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? stripePaymentId;
  final String? refundId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String bookingId;
  final UserModel? user;
  final BookingModel? booking;

  const PaymentModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.stripePaymentId,
    this.refundId,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.bookingId,
    this.user,
    this.booking,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => _$PaymentModelFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentModelToJson(this);

  PaymentModel copyWith({
    String? id,
    double? amount,
    String? currency,
    PaymentStatus? status,
    String? stripePaymentId,
    String? refundId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? bookingId,
    UserModel? user,
    BookingModel? booking,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      stripePaymentId: stripePaymentId ?? this.stripePaymentId,
      refundId: refundId ?? this.refundId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      bookingId: bookingId ?? this.bookingId,
      user: user ?? this.user,
      booking: booking ?? this.booking,
    );
  }

  // Getters útiles
  String get formattedAmount {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      default:
        return '${amount.toStringAsFixed(2)} $currency';
    }
  }

  String get statusDisplayName => status.displayName;

  bool get isSuccessful => status == PaymentStatus.completed;
  
  bool get isPending => status == PaymentStatus.pending;
  
  bool get hasFailed => status == PaymentStatus.failed;
  
  bool get isRefunded => status == PaymentStatus.refunded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PaymentModel{id: $id, amount: $amount, status: $status}';
  }
}

@JsonEnum()
enum PaymentStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('FAILED')
  failed,
  @JsonValue('REFUNDED')
  refunded,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pendiente';
      case PaymentStatus.completed:
        return 'Completado';
      case PaymentStatus.failed:
        return 'Fallido';
      case PaymentStatus.refunded:
        return 'Reembolsado';
    }
  }

  String get color {
    switch (this) {
      case PaymentStatus.pending:
        return 'orange';
      case PaymentStatus.completed:
        return 'green';
      case PaymentStatus.failed:
        return 'red';
      case PaymentStatus.refunded:
        return 'purple';
    }
  }
}