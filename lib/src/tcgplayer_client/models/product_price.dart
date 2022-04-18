import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_price.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class ProductPrice extends ApiResult {
  int productId;
  int lowPrice;
  int midPrice;
  int highPrice;
  int marketPrice;
  int directLowPrice;
  String subTypeName;

  ProductPrice({
    required this.productId,
    required this.lowPrice,
    required this.midPrice,
    required this.highPrice,
    required this.marketPrice,
    required this.directLowPrice,
    required this.subTypeName,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) => _$ProductPriceFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ProductPriceToJson(this);
}
