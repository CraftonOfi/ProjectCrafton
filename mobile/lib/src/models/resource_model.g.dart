// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResourceModel _$ResourceModelFromJson(Map<String, dynamic> json) =>
    ResourceModel(
      id: json['id'] is int
          ? (json['id'] as int).toString()
          : json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: $enumDecode(_$ResourceTypeEnumMap, json['type']),
      pricePerHour: (json['pricePerHour'] as num).toDouble(),
      location: json['location'] as String?,
      capacity: json['capacity'] as String?,
      specifications: json['specifications'] as Map<String, dynamic>?,
      images:
          (json['images'] as List<dynamic>).map((e) => e as String).toList(),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      ownerId: json['ownerId'] is int
          ? (json['ownerId'] as int).toString()
          : json['ownerId'] as String,
      owner: json['owner'] == null
          ? null
          : UserModel.fromJson(json['owner'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ResourceModelToJson(ResourceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'type': _$ResourceTypeEnumMap[instance.type]!,
      'pricePerHour': instance.pricePerHour,
      'location': instance.location,
      'capacity': instance.capacity,
      'specifications': instance.specifications,
      'images': instance.images,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'ownerId': instance.ownerId,
      'owner': instance.owner,
    };

const _$ResourceTypeEnumMap = {
  ResourceType.storageSpace: 'STORAGE_SPACE',
  ResourceType.laserMachine: 'LASER_MACHINE',
};
