// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductCache _$ProductCacheFromJson(Map<String, dynamic> json) => ProductCache(
      timestamp: DateTime.parse(json['timestamp'] as String),
      categoryList: (json['categoryList'] as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
      groupList: (json['groupList'] as List<dynamic>)
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList(),
      conditionsByCategoryId:
          (json['conditionsByCategoryId'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            int.parse(k),
            (e as List<dynamic>)
                .map((e) => Condition.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
      printingsByCategoryId:
          (json['printingsByCategoryId'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            int.parse(k),
            (e as List<dynamic>)
                .map((e) => Printing.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
      raritiesByCategoryId:
          (json['raritiesByCategoryId'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            int.parse(k),
            (e as List<dynamic>)
                .map((e) => Rarity.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
      productList: (json['productList'] as List<dynamic>)
          .map((e) => ProductExtended.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProductCacheToJson(ProductCache instance) =>
    <String, dynamic>{
      'timestamp': ProductCache._timeStampToJson(instance.timestamp),
      'categoryList': instance.categoryList,
      'groupList': instance.groupList,
      'conditionsByCategoryId': instance.conditionsByCategoryId
          .map((k, e) => MapEntry(k.toString(), e)),
      'printingsByCategoryId': instance.printingsByCategoryId
          .map((k, e) => MapEntry(k.toString(), e)),
      'raritiesByCategoryId': instance.raritiesByCategoryId
          .map((k, e) => MapEntry(k.toString(), e)),
      'productList': instance.productList,
    };
