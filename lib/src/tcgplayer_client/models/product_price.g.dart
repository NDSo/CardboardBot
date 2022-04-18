// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductPrice _$ProductPriceFromJson(Map<String, dynamic> json) => ProductPrice(
      productId: json['productId'] as int,
      lowPrice: json['lowPrice'] as int,
      midPrice: json['midPrice'] as int,
      highPrice: json['highPrice'] as int,
      marketPrice: json['marketPrice'] as int,
      directLowPrice: json['directLowPrice'] as int,
      subTypeName: json['subTypeName'] as String,
    );

Map<String, dynamic> _$ProductPriceToJson(ProductPrice instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'lowPrice': instance.lowPrice,
      'midPrice': instance.midPrice,
      'highPrice': instance.highPrice,
      'marketPrice': instance.marketPrice,
      'directLowPrice': instance.directLowPrice,
      'subTypeName': instance.subTypeName,
    };
