import 'package:json_annotation/json_annotation.dart';

import '../models/condition.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_category_conditions.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllCategoryConditions extends ApiGetRequest<ApiListResponse<Condition>> {
  @JsonKey(ignore: true)
  final int categoryId;

  ListAllCategoryConditions({
    required this.categoryId,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "categories",
      categoryId.toString(),
      "conditions",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllCategoryConditionsToJson(this);

  @override
  ApiListResponse<Condition> parseJsonResponse(Map<String, dynamic> json) => ApiListResponse.fromJson(json, Condition.fromJson);
}
