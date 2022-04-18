// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
      categoryId: json['categoryId'] as int,
      name: json['name'] as String,
      modifiedOn: DateTime.parse(json['modifiedOn'] as String),
      displayName: json['displayName'] as String,
      seoCategoryName: json['seoCategoryName'] as String,
      sealedLabel: json['sealedLabel'] as String?,
      nonSealedLabel: json['nonSealedLabel'] as String?,
      conditionGuideUrl: Uri.parse(json['conditionGuideUrl'] as String),
      isScannable: json['isScannable'] as bool,
      popularity: json['popularity'] as int,
    );

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
      'categoryId': instance.categoryId,
      'name': instance.name,
      'modifiedOn': instance.modifiedOn.toIso8601String(),
      'displayName': instance.displayName,
      'seoCategoryName': instance.seoCategoryName,
      'sealedLabel': instance.sealedLabel,
      'nonSealedLabel': instance.nonSealedLabel,
      'conditionGuideUrl': instance.conditionGuideUrl.toString(),
      'isScannable': instance.isScannable,
      'popularity': instance.popularity,
    };
