// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiListResponse<Result> _$ApiListResponseFromJson<Result extends ApiResult>(
  Map<String, dynamic> json,
  Result Function(Object? json) fromJsonResult,
) =>
    ApiListResponse<Result>(
      success: json['success'] as bool,
      errors:
          (json['errors'] as List<dynamic>).map((e) => e as String).toList(),
      results: (json['results'] as List<dynamic>).map(fromJsonResult).toList(),
    );

Map<String, dynamic> _$ApiListResponseToJson<Result extends ApiResult>(
  ApiListResponse<Result> instance,
  Object? Function(Result value) toJsonResult,
) =>
    <String, dynamic>{
      'success': instance.success,
      'errors': instance.errors,
      'results': instance.results.map(toJsonResult).toList(),
    };

ApiPagedResponse<Result> _$ApiPagedResponseFromJson<Result extends ApiResult>(
  Map<String, dynamic> json,
  Result Function(Object? json) fromJsonResult,
) =>
    ApiPagedResponse<Result>(
      success: json['success'] as bool,
      errors:
          (json['errors'] as List<dynamic>).map((e) => e as String).toList(),
      results: (json['results'] as List<dynamic>).map(fromJsonResult).toList(),
      totalItems: json['totalItems'] as int? ?? 0,
    );

Map<String, dynamic> _$ApiPagedResponseToJson<Result extends ApiResult>(
  ApiPagedResponse<Result> instance,
  Object? Function(Result value) toJsonResult,
) =>
    <String, dynamic>{
      'success': instance.success,
      'errors': instance.errors,
      'results': instance.results.map(toJsonResult).toList(),
      'totalItems': instance.totalItems,
    };
