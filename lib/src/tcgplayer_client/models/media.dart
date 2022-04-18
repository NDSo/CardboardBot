import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'media.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Media extends ApiResult {
  String mediaType;
  List<MediaContent> contentList;

  Media({
    required this.mediaType,
    required this.contentList,
  });

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

@JsonSerializable(ignoreUnannotated: false)
class MediaContent extends ApiResult {
  Uri url;
  int displayOrder;

  MediaContent({
    required this.url,
    required this.displayOrder,
  });

  factory MediaContent.fromJson(Map<String, dynamic> json) => _$MediaContentFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MediaContentToJson(this);
}
