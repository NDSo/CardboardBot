import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sku_price_cache.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class SkuPriceCache {
  static String _timeStampToJson(DateTime ts) => ts.toUtc().toIso8601String();
  @JsonKey(toJson: _timeStampToJson)
  final DateTime timestamp;
  @JsonKey()
  final SkuPrice skuPrice;

  SkuPriceCache({required this.timestamp, required this.skuPrice});

  factory SkuPriceCache.fromJson(Map<String, dynamic> json) => _$SkuPriceCacheFromJson(json);

  Map<String, dynamic> toJson() => _$SkuPriceCacheToJson(this);
}
