import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'condition.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Condition extends ApiResult {
  int conditionId;
  String name;
  String abbreviation;
  int displayOrder;

  Condition({
    required this.conditionId,
    required this.name,
    required this.abbreviation,
    required this.displayOrder,
  });

  factory Condition.fromJson(Map<String, dynamic> json) => _$ConditionFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ConditionToJson(this);
}
