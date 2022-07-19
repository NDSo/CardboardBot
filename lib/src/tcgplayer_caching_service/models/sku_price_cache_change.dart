import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'sku_price_cache.dart';

part 'sku_price_cache_change.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class SkuPriceCacheChange {
  @JsonKey()
  SkuPriceCache? before;
  @JsonKey()
  SkuPriceCache after;

  SkuPriceCacheChange({required this.before, required this.after});

  factory SkuPriceCacheChange.fromJson(Map<String, dynamic> json) => _$SkuPriceCacheChangeFromJson(json);

  Map<String, dynamic> toJson() => _$SkuPriceCacheChangeToJson(this);

  String toJsonString() => jsonEncode(this);
}
