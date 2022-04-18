// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rarity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rarity _$RarityFromJson(Map<String, dynamic> json) => Rarity(
      rarityId: json['rarityId'] as int,
      displayText: json['displayText'] as String,
      dbValue: json['dbValue'] as String,
    );

Map<String, dynamic> _$RarityToJson(Rarity instance) => <String, dynamic>{
      'rarityId': instance.rarityId,
      'displayText': instance.displayText,
      'dbValue': instance.dbValue,
    };
