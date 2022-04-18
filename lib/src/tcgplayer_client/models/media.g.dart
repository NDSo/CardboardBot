// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
      mediaType: json['mediaType'] as String,
      contentList: (json['contentList'] as List<dynamic>)
          .map((e) => MediaContent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
      'mediaType': instance.mediaType,
      'contentList': instance.contentList,
    };

MediaContent _$MediaContentFromJson(Map<String, dynamic> json) => MediaContent(
      url: Uri.parse(json['url'] as String),
      displayOrder: json['displayOrder'] as int,
    );

Map<String, dynamic> _$MediaContentToJson(MediaContent instance) =>
    <String, dynamic>{
      'url': instance.url.toString(),
      'displayOrder': instance.displayOrder,
    };
