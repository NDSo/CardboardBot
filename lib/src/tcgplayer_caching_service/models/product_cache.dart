import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_cache.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class ProductCache {
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
  final List<ProductExtended> productList;

  final Map<int, Category> categoryById;
  final Map<int, Group> groupById;
  final Map<int, ProductExtended> productById;

  ProductCache({
    required this.timestamp,
    required this.categoryList,
    required this.groupList,
    required this.conditionsByCategoryId,
    required this.printingsByCategoryId,
    required this.raritiesByCategoryId,
    required this.productList,
  })  : categoryById = Map<int, Category>.fromIterables(
    categoryList.map((e) => e.categoryId),
    categoryList,
  ),
        groupById = Map<int, Group>.fromIterables(
          groupList.map((e) => e.groupId),
          groupList,
        ),
        productById = Map<int, ProductExtended>.fromIterables(
          productList.map((e) => e.productId),
          productList,
        );

  factory ProductCache.empty() => ProductCache(
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    categoryList: [],
    conditionsByCategoryId: {},
    printingsByCategoryId: {},
    raritiesByCategoryId: {},
    groupList: [],
    productList: [],
  );

  factory ProductCache.fromJson(Map<String, dynamic> json) => _$ProductCacheFromJson(json);

  Map<String, dynamic> toJson() => _$ProductCacheToJson(this);
}
