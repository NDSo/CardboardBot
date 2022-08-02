import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:logging/logging.dart';
import 'package:cardboard_bot/extensions.dart';

import '../config/constants.dart';

class TcgPlayerGroupSummaryCommand extends CommandOptionBuilder {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerGroupSummaryCommand");
  static const String _categoryArg = "category";
  static const String _groupArg = "group";

  TcgPlayerGroupSummaryCommand({required TcgPlayerCachingClient tcgPlayerService})
      : super(
          CommandOptionType.subCommand,
          "group_summary",
          "display set market info",
          options: [
            CommandOptionBuilder(
              CommandOptionType.string,
              _categoryArg,
              "category name",
              required: true,
            )..registerAutocompleteHandler((p0) => _alertAddAutoCompleteHandler(event: p0, tcgPlayerService: tcgPlayerService)),
            CommandOptionBuilder(
              CommandOptionType.string,
              _groupArg,
              "group name",
              required: true,
            )..registerAutocompleteHandler((p0) => _alertAddAutoCompleteHandler(event: p0, tcgPlayerService: tcgPlayerService)),
          ],
        ) {
    registerHandler((p0) => _infoHandler(context: p0, tcgPlayerService: tcgPlayerService));
  }

  static Future<void> _alertAddAutoCompleteHandler({required IAutocompleteInteractionEvent event, required TcgPlayerCachingClient tcgPlayerService}) async {
    switch (event.focusedOption.name) {
      case _categoryArg:
        return event.respond(
          tcgPlayerService
              .searchCategories(anyName: RegExp("${event.focusedOption.value}", caseSensitive: false))
              .toSet()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((a, b) => a.name.length.compareTo(b.name.length))
              .sorted((b, a) => a.popularity.compareTo(b.popularity))
              .map((e) => ArgChoiceBuilder(e.displayName.substringSafe(0, 100), e.categoryId.toString()))
              .toList()
              .subListSafe(0, 25),
        );
      case _groupArg:
        return event.respond(
          tcgPlayerService
              .searchGroups(
                categoryId: int.parse(event.options.where((element) => element.name == _categoryArg).first.value as String),
                name: RegExp("${event.focusedOption.value}", caseSensitive: false),
              )
              .toSet()
              .sorted((b, a) => a.publishedOn.compareTo(b.publishedOn))
              .map((e) => ArgChoiceBuilder(e.name.substringSafe(0, 100), e.groupId.toString()))
              .toList()
              .subListSafe(0, 25),
        );
    }
  }

  static Future<void> _infoHandler({required ISlashCommandInteractionEvent context, required TcgPlayerCachingClient tcgPlayerService}) async {
    await context.acknowledge();
    int categoryId = int.parse(context.getArg(_categoryArg).value as String);
    int groupId = int.parse(context.getArg(_groupArg).value as String);

    Category category = tcgPlayerService.searchCategories(categoryId: categoryId).first;
    Group group = tcgPlayerService.searchGroups(groupId: groupId).first;

    List<ProductWrapper> products = (await tcgPlayerService
        .searchProductsByGroupId(groupId: groupId))
        .map((e) => e.wrap(tcgPlayerService))
        .where((product) => product.extendedData.any((extendedData) => RegExp("rarity", caseSensitive: false).hasMatch(extendedData.name)))
        .toList();
    Map<int, SkuPriceCache> skuPrices =
        await tcgPlayerService.getSkuPriceCache(skuIds: products.expand((product) => product.skus.map((sku) => sku.skuId)).toList());

    Set<Printing> printings = products.expand((product) => product.skus.map((sku) => sku.printing)).toSet();

    Map<Printing, Map<String?, List<ProductWrapper>>> productsByRarityByPrinting = {
      for (var printing in printings)
        printing: products.where((product) => product.skus.any((sku) => sku.printing == printing)).fold<Map<String?, List<ProductWrapper>>>(
          {},
          (productsByRarity, product) => productsByRarity
            ..update(
              product.extendedData.tryFirstWhere((extendedData) => RegExp("rarity", caseSensitive: false).hasMatch(extendedData.name))!.value,
              (value) => value..add(product),
              ifAbsent: () => [product],
            ),
        )
    };

    Map<Printing, Map<String?, int>> countByRarityByPrinting = productsByRarityByPrinting.map(
      (printing, productsByRarity) => MapEntry(printing, productsByRarity.map((rarity, products) => MapEntry(rarity, products.length))),
    );

    Map<Printing, Map<String?, num?>> averagePriceByRarityByPrinting = productsByRarityByPrinting.map(
      (printing, productsByRarity) => MapEntry(
        printing,
        productsByRarity.map(
          (rarity, products) => MapEntry(
            rarity,
            products
                .map<num?>(
                  (product) => product.skus
                      .where((sku) => RegExp("mint", caseSensitive: false).hasMatch(sku.condition.name) && sku.printing == printing)
                      // .map((sku) {
                      //   String price = "${sku.skuId}: ${skuPrices.get(sku.skuId)?.skuPrice.lowPrice} ${skuPrices.get(sku.skuId)?.skuPrice.marketPrice}";
                      //   if (rarity == "Rare") _logger.info(price);
                      //   return sku;
                      // })
                      .map<num?>((sku) => skuPrices.get(sku.skuId)?.skuPrice.lowPrice ?? skuPrices.get(sku.skuId)?.skuPrice.marketPrice)
                      .whereType<num>()
                      .average(),
                )
                // .map((e) {
                //   if (rarity == "Rare") _logger.info(e);
                //   return e;
                // })
                .whereType<num>()
                .average(),
          ),
        ),
      ),
    );

    Map<Printing, num> setPriceByPrinting = averagePriceByRarityByPrinting.map((printing, averagePriceByRarity) => MapEntry(
        printing,
        averagePriceByRarity
            .map((rarity, averagePrice) => MapEntry(rarity, (averagePrice ?? 0) * (countByRarityByPrinting.get(printing)?.get(rarity) ?? 0)))
            .values
            .sum()));

    await context.respond(MessageBuilder.empty()
      ..embeds = [
        EmbedBuilder()
          ..color = botColor
          ..addAuthor((author) => author.name = category.displayName)
          ..title = "${group.name}"
          ..description = "Set Total: ${setPriceByPrinting.values.sum().toFormat(usdFormat)}"
          ..timestamp = skuPrices.values
              .map((e) => e.timestamp)
              .fold<DateTime>(DateTime.now(), (previousValue, element) => previousValue.isBefore(element) ? previousValue : element)
          ..addFooter((footer) {
            footer.text = products.tryFirst()?.url.host;
          }),
        for (var printing in printings.sorted((a, b) => a.displayOrder.compareTo(b.displayOrder)))
          EmbedBuilder()
            ..color = botColor
            ..title = printing.name
            ..description = "Printing Total: ${setPriceByPrinting.get(printing)?.toFormat(usdFormat)}"
            ..fields = productsByRarityByPrinting
                .get(printing)!
                .keys
                .sorted(
                  (a, b) =>
                      -1 * ((averagePriceByRarityByPrinting.get(printing)?.get(a) ?? 0).compareTo(averagePriceByRarityByPrinting.get(printing)?.get(b) ?? 0)),
                )
                .map<EmbedFieldBuilder>((rarity) => EmbedFieldBuilder(
                      rarity,
                      "${countByRarityByPrinting.get(printing)?.get(rarity)} - ${averagePriceByRarityByPrinting.get(printing)?.get(rarity)?.toFormat(usdFormat)}",
                      true,
                    ))
                .toList(),
      ]);
  }
}
