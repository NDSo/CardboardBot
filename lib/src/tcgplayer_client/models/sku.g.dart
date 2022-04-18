// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sku.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sku _$SkuFromJson(Map<String, dynamic> json) => Sku(
      skuId: json['skuId'] as int,
      productId: json['productId'] as int,
      languageId: json['languageId'] as int,
      printingId: json['printingId'] as int,
      conditionId: json['conditionId'] as int,
    );

Map<String, dynamic> _$SkuToJson(Sku instance) => <String, dynamic>{
      'skuId': instance.skuId,
      'productId': instance.productId,
      'languageId': instance.languageId,
      'printingId': instance.printingId,
      'conditionId': instance.conditionId,
    };
