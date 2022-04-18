import 'sku.dart';

import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Product extends ApiResult {
  final int productId;
  final String name;
  final String? cleanName;
  final Uri imageUrl;
  final int categoryId;
  final int groupId;
  final Uri url;
  final DateTime modifiedOn;

  Product({
    required this.productId,
    required this.name,
    required this.cleanName,
    required this.imageUrl,
    required this.categoryId,
    required this.groupId,
    required this.url,
    required this.modifiedOn,
  });

  bool matchAnyName(RegExp regExp) => regExp.hasMatch(name) || regExp.hasMatch(cleanName ?? "");

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}

@JsonSerializable(ignoreUnannotated: false)
class ProductExtended extends Product {
  // With getExtendedFields
  final int imageCount;
  final PresaleInfo presaleInfo;
  @JsonKey(defaultValue: [])
  final List<ExtendedData> extendedData;

  // With includeSkus
  @JsonKey(defaultValue: [])
  final List<Sku> skus;

  ProductExtended({
    required int productId,
    required String name,
    required String? cleanName,
    required Uri imageUrl,
    required int categoryId,
    required int groupId,
    required Uri url,
    required DateTime modifiedOn,
    required this.imageCount,
    required this.presaleInfo,
    required this.extendedData,
    required this.skus,
  }) : super(
          productId: productId,
          name: name,
          cleanName: cleanName,
          imageUrl: imageUrl,
          categoryId: categoryId,
          groupId: groupId,
          url: url,
          modifiedOn: modifiedOn,
        );

  factory ProductExtended.fromJson(Map<String, dynamic> json) => _$ProductExtendedFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ProductExtendedToJson(this);
}

@JsonSerializable(ignoreUnannotated: false)
class PresaleInfo {
  bool isPresale;
  DateTime? releasedOn;
  String? note;

  PresaleInfo({
    required this.isPresale,
    this.releasedOn,
    this.note,
  });

  factory PresaleInfo.fromJson(Map<String, dynamic> json) => _$PresaleInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PresaleInfoToJson(this);
}

@JsonSerializable(ignoreUnannotated: false)
class ExtendedData {
  String name;
  String displayName;
  String value;

  ExtendedData({
    required this.name,
    required this.displayName,
    required this.value,
  });

  factory ExtendedData.fromJson(Map<String, dynamic> json) => _$ExtendedDataFromJson(json);

  Map<String, dynamic> toJson() => _$ExtendedDataToJson(this);
}
