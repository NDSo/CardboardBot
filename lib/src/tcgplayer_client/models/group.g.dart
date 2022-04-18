// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Group _$GroupFromJson(Map<String, dynamic> json) => Group(
      groupId: json['groupId'] as int,
      categoryId: json['categoryId'] as int,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      isSupplemental: json['isSupplemental'] as bool,
      publishedOn: DateTime.parse(json['publishedOn'] as String),
      modifiedOn: DateTime.parse(json['modifiedOn'] as String),
    );

Map<String, dynamic> _$GroupToJson(Group instance) => <String, dynamic>{
      'groupId': instance.groupId,
      'categoryId': instance.categoryId,
      'name': instance.name,
      'abbreviation': instance.abbreviation,
      'isSupplemental': instance.isSupplemental,
      'publishedOn': instance.publishedOn.toIso8601String(),
      'modifiedOn': instance.modifiedOn.toIso8601String(),
    };
