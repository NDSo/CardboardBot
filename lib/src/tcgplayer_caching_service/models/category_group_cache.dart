import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_group_cache.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class CategoryGroupCache {
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
  final Map<int, Map<int, Set<int>>> skuIdByProductIdByGroupId;

  final Map<int, Category> categoryById;
  final Map<int, Group> groupById;
  final Map<int, int> productIdBySkuId;
  final Map<int, int> groupIdByProductId;

  CategoryGroupCache({
    required this.timestamp,
    required this.categoryList,
    required this.groupList,
    required this.conditionsByCategoryId,
    required this.printingsByCategoryId,
    required this.raritiesByCategoryId,
    required this.skuIdByProductIdByGroupId,
  })  : categoryById = Map<int, Category>.fromIterables(
          categoryList.map((e) => e.categoryId),
          categoryList,
        ),
        groupById = Map<int, Group>.fromIterables(
          groupList.map((e) => e.groupId),
          groupList,
        ),
        groupIdByProductId = skuIdByProductIdByGroupId.entries.fold<Map<int, int>>(
          <int, int>{},
          (t1, e1) => t1..addAll({for (var productId in e1.value.keys) productId: e1.key}),
        ),
        productIdBySkuId = skuIdByProductIdByGroupId.entries.fold<Map<int, int>>(
          <int, int>{},
          (t1, e1) => t1
            ..addAll(e1.value.entries.fold(
              <int, int>{},
              (t2, e2) => t2..addAll({for (var skuId in e2.value) skuId: e2.key}),
            )),
        );

  CategoryGroupCache.empty()
      : timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        categoryList = [],
        conditionsByCategoryId = {},
        printingsByCategoryId = {},
        raritiesByCategoryId = {},
        groupList = [],
        categoryById = {},
        groupById = {},
        productIdBySkuId = {},
        groupIdByProductId = {},
        skuIdByProductIdByGroupId = {};

  factory CategoryGroupCache.fromJson(Map<String, dynamic> json) => _$CategoryGroupCacheFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryGroupCacheToJson(this);
}
