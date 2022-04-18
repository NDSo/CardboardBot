import 'package:json_annotation/json_annotation.dart';

import '../models/rarity.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_category_rarities.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllCategoryRarities extends ApiGetRequest<ApiListResponse<Rarity>> {
  @JsonKey(ignore: true)
  final int categoryId;

  ListAllCategoryRarities({
    required this.categoryId,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "categories",
      categoryId.toString(),
      "rarities",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllCategoryRaritiesToJson(this);

  @override
  ApiListResponse<Rarity> parseJsonResponse(Map<String, dynamic> json) => ApiListResponse.fromJson(json, Rarity.fromJson);
}
