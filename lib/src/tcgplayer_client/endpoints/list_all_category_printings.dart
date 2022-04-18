import 'package:json_annotation/json_annotation.dart';

import '../models/printing.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_category_printings.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllCategoryPrintings extends ApiGetRequest<ApiListResponse<Printing>> {
  @JsonKey(ignore: true)
  final int categoryId;

  ListAllCategoryPrintings({
    required this.categoryId,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "categories",
      categoryId.toString(),
      "printings",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllCategoryPrintingsToJson(this);

  @override
  ApiListResponse<Printing> parseJsonResponse(Map<String, dynamic> json) => ApiListResponse.fromJson(json, Printing.fromJson);
}
