import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';

part 'resource_model.g.dart';

@JsonSerializable()
class ResourceModel {
  final String id;
  final String name;
  final String description;
  final ResourceType type;
  final double pricePerHour;
  final String? location;
  final String? capacity;
  final Map<String, dynamic>? specifications;
  final List<String> images;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerId;
  final UserModel? owner;

  const ResourceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.pricePerHour,
    this.location,
    this.capacity,
    this.specifications,
    required this.images,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.owner,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) => _$ResourceModelFromJson(json);
  Map<String, dynamic> toJson() => _$ResourceModelToJson(this);

  ResourceModel copyWith({
    String? id,
    String? name,
    String? description,
    ResourceType? type,
    double? pricePerHour,
    String? location,
    String? capacity,
    Map<String, dynamic>? specifications,
    List<String>? images,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerId,
    UserModel? owner,
  }) {
    return ResourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      specifications: specifications ?? this.specifications,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerId: ownerId ?? this.ownerId,
      owner: owner ?? this.owner,
    );
  }

  // Getters útiles
  String get formattedPrice => '€${pricePerHour.toStringAsFixed(2)}/hora';
  
  String get typeDisplayName => type.displayName;
  
  String get primaryImage => images.isNotEmpty ? images.first : '';
  
  bool get hasLocation => location != null && location!.isNotEmpty;
  
  bool get hasImages => images.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ResourceModel{id: $id, name: $name, type: $type, price: $pricePerHour}';
  }
}

@JsonEnum()
enum ResourceType {
  @JsonValue('STORAGE_SPACE')
  storageSpace,
  @JsonValue('LASER_MACHINE')
  laserMachine,
}

extension ResourceTypeExtension on ResourceType {
  String get displayName {
    switch (this) {
      case ResourceType.storageSpace:
        return 'Espacio de Almacén';
      case ResourceType.laserMachine:
        return 'Máquina de Corte Láser';
    }
  }

  String get icon {
    switch (this) {
      case ResourceType.storageSpace:
        return '📦';
      case ResourceType.laserMachine:
        return '⚙️';
    }
  }

  String get description {
    switch (this) {
      case ResourceType.storageSpace:
        return 'Espacios seguros para almacenar tus productos';
      case ResourceType.laserMachine:
        return 'Máquinas de precisión para corte de materiales';
    }
  }
}