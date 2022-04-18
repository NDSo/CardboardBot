// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sku_price_cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkuPriceCache _$SkuPriceCacheFromJson(Map<String, dynamic> json) =>
    SkuPriceCache(
      timestamp: DateTime.parse(json['timestamp'] as String),
      skuPrice: SkuPrice.fromJson(json['skuPrice'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SkuPriceCacheToJson(SkuPriceCache instance) =>
    <String, dynamic>{
      'timestamp': SkuPriceCache._timeStampToJson(instance.timestamp),
      'skuPrice': instance.skuPrice,
    };
