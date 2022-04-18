// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Condition _$ConditionFromJson(Map<String, dynamic> json) => Condition(
      conditionId: json['conditionId'] as int,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      displayOrder: json['displayOrder'] as int,
    );

Map<String, dynamic> _$ConditionToJson(Condition instance) => <String, dynamic>{
      'conditionId': instance.conditionId,
      'name': instance.name,
      'abbreviation': instance.abbreviation,
      'displayOrder': instance.displayOrder,
    };
