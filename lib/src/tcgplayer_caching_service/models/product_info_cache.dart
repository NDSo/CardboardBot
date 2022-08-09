import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_info_cache.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class ProductInfoCache {
  static String _timeStampToJson(DateTime ts) => ts.toUtc().toIso8601String();
  @JsonKey(toJson: _timeStampToJson)
  final DateTime timestamp;
  @JsonKey()
  final int groupId;
  @JsonKey()
  final List<ProductExtended> productList;

  final Map<int, ProductExtended> productById;

  ProductInfoCache({
    required this.timestamp,
    required this.groupId,
    required this.productList,
  }) : productById = {
          for (var product in productList) product.productId: product,
        };

  factory ProductInfoCache.empty(int groupId) => ProductInfoCache(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        groupId: groupId,
        productList: [],
      );

  factory ProductInfoCache.fromJson(Map<String, dynamic> json) => _$ProductInfoCacheFromJson(json);

  Map<String, dynamic> toJson() => _$ProductInfoCacheToJson(this);

  String getId() => buildId(groupId);
  static String buildId(int groupId) => "groupId=$groupId";
}
