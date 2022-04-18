// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sku_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkuPrice _$SkuPriceFromJson(Map<String, dynamic> json) => SkuPrice(
      skuId: json['skuId'] as int,
      lowPrice: json['lowPrice'] as num?,
      lowestShipping: json['lowestShipping'] as num?,
      lowestListingPrice: json['lowestListingPrice'] as num?,
      marketPrice: json['marketPrice'] as num?,
      directLowPrice: json['directLowPrice'] as num?,
    );

Map<String, dynamic> _$SkuPriceToJson(SkuPrice instance) => <String, dynamic>{
      'skuId': instance.skuId,
      'lowPrice': instance.lowPrice,
      'lowestShipping': instance.lowestShipping,
      'lowestListingPrice': instance.lowestListingPrice,
      'marketPrice': instance.marketPrice,
      'directLowPrice': instance.directLowPrice,
    };
