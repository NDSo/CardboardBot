import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rarity.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Rarity extends ApiResult {
  int rarityId;
  String displayText;
  String dbValue;

  Rarity({
    required this.rarityId,
    required this.displayText,
    required this.dbValue,
  });

  factory Rarity.fromJson(Map<String, dynamic> json) => _$RarityFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$RarityToJson(this);
}
