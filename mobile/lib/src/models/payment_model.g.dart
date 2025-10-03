// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
      id: json['id'] is int
          ? (json['id'] as int).toString()
          : json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: $enumDecode(_$PaymentStatusEnumMap, json['status']),
      stripePaymentId: json['stripePaymentId'] as String?,
      refundId: json['refundId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userId: json['userId'] is int
          ? (json['userId'] as int).toString()
          : json['userId'] as String,
      bookingId: json['bookingId'] is int
          ? (json['bookingId'] as int).toString()
          : json['bookingId'] as String,
      user: json['user'] == null
          ? null
          : UserModel.fromJson(json['user'] as Map<String, dynamic>),
      booking: json['booking'] == null
          ? null
          : BookingModel.fromJson(json['booking'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentModelToJson(PaymentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'stripePaymentId': instance.stripePaymentId,
      'refundId': instance.refundId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userId': instance.userId,
      'bookingId': instance.bookingId,
      'user': instance.user,
      'booking': instance.booking,
    };

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'PENDING',
  PaymentStatus.completed: 'COMPLETED',
  PaymentStatus.failed: 'FAILED',
  PaymentStatus.refunded: 'REFUNDED',
};
