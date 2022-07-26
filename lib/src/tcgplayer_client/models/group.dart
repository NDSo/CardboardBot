import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'group.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Group extends ApiResult {
  int groupId;
  int categoryId;
  String name;
  String? abbreviation;
  bool isSupplemental;
  DateTime publishedOn;
  DateTime modifiedOn;

  Group({
    required this.groupId,
    required this.categoryId,
    required this.name,
    required this.abbreviation,
    required this.isSupplemental,
    required this.publishedOn,
    required this.modifiedOn,
  });

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$GroupToJson(this);
}
