import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Category extends ApiResult {
  int categoryId;
  String name;
  DateTime modifiedOn;
  String displayName;
  String seoCategoryName;
  String? sealedLabel;
  String? nonSealedLabel;
  Uri conditionGuideUrl;
  bool isScannable;
  int popularity;

  Category({
    required this.categoryId,
    required this.name,
    required this.modifiedOn,
    required this.displayName,
    required this.seoCategoryName,
    required this.sealedLabel,
    required this.nonSealedLabel,
    required this.conditionGuideUrl,
    required this.isScannable,
    required this.popularity,
  });

  bool matchAnyName(RegExp regExp) => regExp.hasMatch(name) || regExp.hasMatch(displayName) || regExp.hasMatch(seoCategoryName);

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
