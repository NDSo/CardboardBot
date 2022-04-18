// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Language _$LanguageFromJson(Map<String, dynamic> json) => Language(
      languageId: json['languageId'] as int,
      name: json['name'] as String,
      abbr: json['abbr'] as String,
    );

Map<String, dynamic> _$LanguageToJson(Language instance) => <String, dynamic>{
      'languageId': instance.languageId,
      'name': instance.name,
      'abbr': instance.abbr,
    };
