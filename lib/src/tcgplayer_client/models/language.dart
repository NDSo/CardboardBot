import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'language.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Language extends ApiResult {
  int languageId;
  String name;
  String abbr;

  Language({
    required this.languageId,
    required this.name,
    required this.abbr,
  });

  factory Language.fromJson(Map<String, dynamic> json) => _$LanguageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$LanguageToJson(this);
}
