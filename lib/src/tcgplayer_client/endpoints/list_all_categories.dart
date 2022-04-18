import 'package:json_annotation/json_annotation.dart';

import '../models/category.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_categories.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllCategories extends ApiGetPagedRequest<ApiPagedResponse<Category>> {
  final String? sortOrder;
  final bool? sortDesc;

  ListAllCategories({
    this.sortOrder,
    this.sortDesc,
  });

  @override
  List<String> getPathSegments() {
    return const ["catalog", "categories"];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllCategoriesToJson(this);

  @override
  ApiPagedResponse<Category> parseJsonResponse(Map<String, dynamic> json) => ApiPagedResponse.fromJson(json, Category.fromJson);
}
