import 'package:json_annotation/json_annotation.dart';

import '../models/sku_price.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_sku_market_prices.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListSkuMarketPrices extends ApiGetRequest<ApiListResponse<SkuPrice>> {
  @JsonKey(ignore: true)
  final List<int> skuIds;

  ListSkuMarketPrices({required this.skuIds});

  @override
  List<String> getPathSegments() {
    return ["pricing", "sku", skuIds.join(",")];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListSkuMarketPricesToJson(this);

  @override
  ApiListResponse<SkuPrice> parseJsonResponse(Map<String, dynamic> json) => ApiListResponse.fromJson(json, SkuPrice.fromJson);
}
