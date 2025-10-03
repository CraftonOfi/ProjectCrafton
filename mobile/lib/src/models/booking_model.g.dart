// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) => BookingModel(
      id: json['id'] is int
          ? (json['id'] as int).toString()
          : json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      totalHours: (json['totalHours'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userId: json['userId'] is int
          ? (json['userId'] as int).toString()
          : json['userId'] as String,
      resourceId: json['resourceId'] is int
          ? (json['resourceId'] as int).toString()
          : json['resourceId'] as String,
      user: json['user'] == null
          ? null
          : UserModel.fromJson(json['user'] as Map<String, dynamic>),
      resource: json['resource'] == null
          ? null
          : ResourceModel.fromJson(json['resource'] as Map<String, dynamic>),
      payments: (json['payments'] as List<dynamic>?)
          ?.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BookingModelToJson(BookingModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'totalHours': instance.totalHours,
      'totalPrice': instance.totalPrice,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userId': instance.userId,
      'resourceId': instance.resourceId,
      'user': instance.user,
      'resource': instance.resource,
      'payments': instance.payments,
    };

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'PENDING',
  BookingStatus.confirmed: 'CONFIRMED',
  BookingStatus.inProgress: 'IN_PROGRESS',
  BookingStatus.completed: 'COMPLETED',
  BookingStatus.cancelled: 'CANCELLED',
  BookingStatus.refunded: 'REFUNDED',
};
