// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      productId: json['productId'] as int,
      name: json['name'] as String,
      cleanName: json['cleanName'] as String?,
      imageUrl: Uri.parse(json['imageUrl'] as String),
      categoryId: json['categoryId'] as int,
      groupId: json['groupId'] as int,
      url: Uri.parse(json['url'] as String),
      modifiedOn: DateTime.parse(json['modifiedOn'] as String),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'cleanName': instance.cleanName,
      'imageUrl': instance.imageUrl.toString(),
      'categoryId': instance.categoryId,
      'groupId': instance.groupId,
      'url': instance.url.toString(),
      'modifiedOn': instance.modifiedOn.toIso8601String(),
    };

ProductExtended _$ProductExtendedFromJson(Map<String, dynamic> json) =>
    ProductExtended(
      productId: json['productId'] as int,
      name: json['name'] as String,
      cleanName: json['cleanName'] as String?,
      imageUrl: Uri.parse(json['imageUrl'] as String),
      categoryId: json['categoryId'] as int,
      groupId: json['groupId'] as int,
      url: Uri.parse(json['url'] as String),
      modifiedOn: DateTime.parse(json['modifiedOn'] as String),
      imageCount: json['imageCount'] as int,
      presaleInfo:
          PresaleInfo.fromJson(json['presaleInfo'] as Map<String, dynamic>),
      extendedData: (json['extendedData'] as List<dynamic>?)
              ?.map((e) => ExtendedData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      skus: (json['skus'] as List<dynamic>?)
              ?.map((e) => Sku.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ProductExtendedToJson(ProductExtended instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'cleanName': instance.cleanName,
      'imageUrl': instance.imageUrl.toString(),
      'categoryId': instance.categoryId,
      'groupId': instance.groupId,
      'url': instance.url.toString(),
      'modifiedOn': instance.modifiedOn.toIso8601String(),
      'imageCount': instance.imageCount,
      'presaleInfo': instance.presaleInfo,
      'extendedData': instance.extendedData,
      'skus': instance.skus,
    };

PresaleInfo _$PresaleInfoFromJson(Map<String, dynamic> json) => PresaleInfo(
      isPresale: json['isPresale'] as bool,
      releasedOn: json['releasedOn'] == null
          ? null
          : DateTime.parse(json['releasedOn'] as String),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$PresaleInfoToJson(PresaleInfo instance) =>
    <String, dynamic>{
      'isPresale': instance.isPresale,
      'releasedOn': instance.releasedOn?.toIso8601String(),
      'note': instance.note,
    };

ExtendedData _$ExtendedDataFromJson(Map<String, dynamic> json) => ExtendedData(
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      value: json['value'] as String,
    );

Map<String, dynamic> _$ExtendedDataToJson(ExtendedData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'value': instance.value,
    };
