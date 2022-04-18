import 'package:json_annotation/json_annotation.dart';

import '../models/group.dart';
import '../abstracts/api_request.dart';
import '../abstracts/api_response.dart';

part 'list_all_category_groups.g.dart';

@JsonSerializable(ignoreUnannotated: false, createFactory: false)
class ListAllCategoryGroups extends ApiGetPagedRequest<ApiPagedResponse<Group>> {
  @JsonKey(ignore: true)
  final int categoryId;

  ListAllCategoryGroups({
    required this.categoryId,
  });

  @override
  List<String> getPathSegments() {
    return [
      "catalog",
      "categories",
      categoryId.toString(),
      "groups",
    ];
  }

  @override
  Map<String, dynamic>? toJson() => _$ListAllCategoryGroupsToJson(this);

  @override
  ApiPagedResponse<Group> parseJsonResponse(Map<String, dynamic> json) => ApiPagedResponse.fromJson(json, Group.fromJson);
}
