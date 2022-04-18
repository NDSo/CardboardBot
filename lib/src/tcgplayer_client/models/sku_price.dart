import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sku_price.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class SkuPrice extends ApiResult {
  int skuId;
  num? lowPrice;
  num? lowestShipping;
  num? lowestListingPrice;
  num? marketPrice;
  num? directLowPrice;

  SkuPrice({
    required this.skuId,
    required this.lowPrice,
    required this.lowestShipping,
    required this.lowestListingPrice,
    required this.marketPrice,
    required this.directLowPrice,
  });

  factory SkuPrice.fromJson(Map<String, dynamic> json) => _$SkuPriceFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$SkuPriceToJson(this);
}
