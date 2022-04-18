import 'package:json_annotation/json_annotation.dart';

import '../models/product.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_products.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllProducts extends ApiGetPagedRequest<ApiPagedResponse<Product>> {
  final int? categoryId;
  final String? categoryName;
  final int? groupId;
  final String? groupName;
  final String? productName;
  final List<String>? productTypes;

  ListAllProducts({
    this.categoryId,
    this.categoryName,
    this.groupId,
    this.groupName,
    this.productName,
    this.productTypes,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "products",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllProductsToJson(this);

  @override
  ApiPagedResponse<Product> parseJsonResponse(Map<String, dynamic> json) => ApiPagedResponse.fromJson(json, Product.fromJson);
}

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllProductsExtended extends ApiGetPagedRequest<ApiPagedResponse<ProductExtended>> {
  final int? categoryId;
  final String? categoryName;
  final int? groupId;
  final String? groupName;
  final String? productName;
  final bool? getExtendedFields = true;
  final List<String>? productTypes;
  final bool? includeSkus = true;

  ListAllProductsExtended({
    this.categoryId,
    this.categoryName,
    this.groupId,
    this.groupName,
    this.productName,
    this.productTypes,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "products",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllProductsExtendedToJson(this);

  @override
  ApiPagedResponse<ProductExtended> parseJsonResponse(Map<String, dynamic> json) => ApiPagedResponse.fromJson(json, ProductExtended.fromJson);
}
