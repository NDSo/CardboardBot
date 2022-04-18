// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tcgplayer_alert_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TcgPlayerAlertAction _$TcgPlayerAlertActionFromJson(
        Map<String, dynamic> json) =>
    TcgPlayerAlertAction._(
      ownerId: Action.snowflakeFromJson(json['ownerId'] as int),
      skuId: json['skuId'] as int,
      maxPrice: json['maxPrice'] as num?,
    );

Map<String, dynamic> _$TcgPlayerAlertActionToJson(
        TcgPlayerAlertAction instance) =>
    <String, dynamic>{
      'ownerId': Action.snowflakeToJson(instance.ownerId),
      'skuId': instance.skuId,
      'maxPrice': instance.maxPrice,
    };
