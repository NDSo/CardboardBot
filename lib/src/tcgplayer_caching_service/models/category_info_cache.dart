import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_info_cache.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class CategoryInfoCache {
  static String _timeStampToJson(DateTime ts) => ts.toUtc().toIso8601String();
  @JsonKey(toJson: _timeStampToJson)
  final DateTime timestamp;
  @JsonKey()
  final List<Category> categoryList;
  @JsonKey()
  final List<Group> groupList;
  @JsonKey()
  final Map<int, List<Condition>> conditionsByCategoryId;
  @JsonKey()
  final Map<int, List<Printing>> printingsByCategoryId;
  @JsonKey()
  final Map<int, List<Rarity>> raritiesByCategoryId;
  @JsonKey()
  final Map<int, int> groupIdByProductId; // 6mb, needed for rich embeds

  final Map<int, Category> categoryById;
  final Map<int, Group> groupById;

  CategoryInfoCache({
    required this.timestamp,
    required this.categoryList,
    required this.groupList,
    required this.conditionsByCategoryId,
    required this.printingsByCategoryId,
    required this.raritiesByCategoryId,
    required this.groupIdByProductId,
  })  : categoryById = Map<int, Category>.fromIterables(
          categoryList.map((e) => e.categoryId),
          categoryList,
        ),
        groupById = Map<int, Group>.fromIterables(
          groupList.map((e) => e.groupId),
          groupList,
        );

  CategoryInfoCache.empty()
      : timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        categoryList = [],
        conditionsByCategoryId = {},
        printingsByCategoryId = {},
        raritiesByCategoryId = {},
        groupList = [],
        groupIdByProductId = {},
        categoryById = {},
        groupById = {};

  factory CategoryInfoCache.fromJson(Map<String, dynamic> json) => _$CategoryInfoCacheFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryInfoCacheToJson(this);

  String getId() => buildId();

  static String buildId() => "CategoryInfoCache";
}
