import 'package:json_annotation/json_annotation.dart';

import '../models/product_price.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_product_prices_by_group.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListProductPricesByGroup extends ApiGetRequest<ApiListResponse<ProductPrice>> {
  @JsonKey(ignore: true)
  final int groupId;

  ListProductPricesByGroup({required this.groupId});

  @override
  List<String> getPathSegments() {
    return ["pricing", "group", groupId.toString()];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListProductPricesByGroupToJson(this);

  @override
  ApiListResponse<ProductPrice> parseJsonResponse(Map<String, dynamic> json) => ApiListResponse.fromJson(json, ProductPrice.fromJson);
}
