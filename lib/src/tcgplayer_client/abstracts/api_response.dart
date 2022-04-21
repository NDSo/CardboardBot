import 'package:json_annotation/json_annotation.dart';

import 'api_result.dart';

part 'api_response.g.dart';

abstract class ApiBaseResponse {
  bool success;
  List<String> errors;

  ApiBaseResponse({
    required this.success,
    required this.errors,
  });

  Map<String, dynamic> toJson();
}

mixin ResultsField<T extends ApiResult> on ApiBaseResponse {
  abstract List<T> results;
}

mixin TotalItemsField on ApiBaseResponse {
  abstract int totalItems;
}

@JsonSerializable(ignoreUnannotated: false, genericArgumentFactories: true)
class ApiListResponse<Result extends ApiResult> extends ApiBaseResponse with ResultsField<Result> {
  @override
  List<Result> results;

  ApiListResponse({
    required bool success,
    required List<String> errors,
    required this.results,
  }) : super(
          success: success,
          errors: errors,
        );

  factory ApiListResponse.fromJson(Map<String, dynamic> json, Result Function(Map<String, dynamic> json) fromJsonResult) => _$ApiListResponseFromJson(
        json,
        (Object? object) => fromJsonResult(object as Map<String, dynamic>),
      );

  @override
  Map<String, dynamic> toJson() => _$ApiListResponseToJson(this, (Result result) => result.toJson());
}

@JsonSerializable(ignoreUnannotated: false, genericArgumentFactories: true)
class ApiPagedResponse<Result extends ApiResult> extends ApiBaseResponse with ResultsField<Result>, TotalItemsField {
  @override
  List<Result> results;
  @override
  @JsonKey(defaultValue: 0) // NULL ON ERROR OF "NO RESULTS FOUND"...
  int totalItems;

  ApiPagedResponse({
    required bool success,
    required List<String> errors,
    required this.results,
    required this.totalItems,
  }) : super(
          success: success,
          errors: errors,
        );

  factory ApiPagedResponse.fromJson(Map<String, dynamic> json, Result Function(Map<String, dynamic> json) fromJsonResult) => _$ApiPagedResponseFromJson(
        json,
        (Object? object) => fromJsonResult(object as Map<String, dynamic>),
      );

  @override
  Map<String, dynamic> toJson() => _$ApiPagedResponseToJson(this, (Result result) => result.toJson());
}
