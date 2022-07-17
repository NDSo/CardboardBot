import 'dart:async';
import 'package:cardboard_bot/nyxx_bot_actions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nyxx/nyxx.dart';
import 'package:cardboard_bot/extensions.dart';

import '../config/constants.dart';

part 'tcgplayer_alert_action.g.dart';

@JsonSerializable(ignoreUnannotated: true, constructor: "_")
class TcgPlayerAlertAction extends Action {
  StreamSubscription<SkuPriceCacheChange?>? _tcgplayerSkuPriceSubscription;

  @JsonKey()
  final int skuId;
  @JsonKey()
  final num? maxPrice;

  TcgPlayerAlertAction._({
    required Snowflake ownerId,
    required this.skuId,
    required this.maxPrice,
  }) : super(ownerId: ownerId);

  factory TcgPlayerAlertAction.create({required Snowflake ownerId, required int skuId, required num maxPrice}) =>
      TcgPlayerAlertAction._(ownerId: ownerId, skuId: skuId, maxPrice: maxPrice);

  factory TcgPlayerAlertAction.fromJson(Map<String, dynamic> json) => _$TcgPlayerAlertActionFromJson(json);

  void boot(INyxxWebsocket bot, TcgPlayerCachingService tcgPlayerService) {
    _tcgplayerSkuPriceSubscription = tcgPlayerService.onHighPrioritySkuPriceCacheChange
        .where(
          (skuPriceChanges) => skuPriceChanges.get(skuId) != null,
    )
        .map<SkuPriceCacheChange>(
          (skuPriceChanges) => skuPriceChanges.get(skuId)!,
    )
        .where(
          (skuPriceChange) =>
      ((skuPriceChange.after.skuPrice.lowestListingPrice ?? double.infinity) < (skuPriceChange.before?.skuPrice.lowestListingPrice ?? double.infinity)) &&
          ((skuPriceChange.after.skuPrice.lowestListingPrice ?? double.infinity) <= (maxPrice ?? double.infinity)),
    )
        .listen(
          (skuPriceChange) async =>
          (await bot.fetchUser(ownerId)).sendMessage(MessageBuilder.embed(_buildProductEmbed(
              product: tcgPlayerService.searchProductsWrapped(skuId: skuId).tryFirst()!,
              skuPriceChange: skuPriceChange,
              botColor: botColor,
          ))),
    );
  }

  void shutdown() {
    _tcgplayerSkuPriceSubscription?.cancel();
  }

  @override
  String getId() {
    return "$ownerId|$skuId";
  }

  @override
  Map<String, dynamic> toJson() => _$TcgPlayerAlertActionToJson(this);

  EmbedBuilder _buildProductEmbed({required ProductWrapper product, required SkuPriceCacheChange skuPriceChange, required DiscordColor? botColor}) {
    SkuWrapper sku = product.skus.firstWhere((element) => element.skuId == skuId);

    EmbedBuilder embedBuilder = EmbedBuilder()
      ..color = botColor
      ..addAuthor((author) {
        author.name =
        "${product.group.name}${product.extendedData.where((element) => RegExp("number", caseSensitive: false).hasMatch(element.name)).map((e) => " | ${e
            .value}").tryFirst(orElse: "")}";
      })
      ..title = "${product.name}"
      ..url = product.url.toDiscordString()
      ..imageUrl = product.imageUrl.toDiscordString()
      ..description = MessageDecoration.bold.format("${sku.condition.name}\n${sku.printing.name}")
      ..fields = [
        EmbedFieldBuilder(
          "Lowest Listing",
          "${skuPriceChange.after.skuPrice.lowPrice?.toFormat(usdFormat)}\n${MessageDecoration.strike.format(
              "${skuPriceChange.before?.skuPrice.lowPrice?.toFormat(usdFormat)}")}",
          true,
        ),
        EmbedFieldBuilder(
          "Trigger",
          "${maxPrice?.toFormat(usdFormat) ?? "any"}",
          true,
        )
      ]
      ..timestamp = skuPriceChange.after.timestamp
      ..addFooter((footer) {
        footer.text = product.url.host;
      })
      ..trimToMaxLength();

    return embedBuilder;
  }
}
