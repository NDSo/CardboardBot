import 'dart:math';

import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:logging/logging.dart';
import 'package:cardboard_bot/extensions.dart';

import '../config/constants.dart';

class TcgPlayerSearchCommand extends CommandOptionBuilder {
  // ignore: unused_field
  static final Logger _logger = Logger("TcgPlayerSearchCommand");
  static const String _nameArg = "name";
  static const String _groupFilterArg = "group";
  static const String _categoryFilterArg = "category";

  TcgPlayerSearchCommand({required TcgPlayerCachingClient tcgPlayerService})
      : super(
          CommandOptionType.subCommand,
          "search",
          "search for product info",
          options: [
            CommandOptionBuilder(
              CommandOptionType.string,
              _categoryFilterArg,
              "set category",
              required: true,
            )..registerAutocompleteHandler(
                (p0) async => p0.respond(
                  (await tcgPlayerService.searchCategories(anyName: RegExp(p0.focusedOption.value as String, caseSensitive: false)))
                      .sorted((a, b) => a.name.compareTo(b.name))
                      .sorted((b, a) => a.popularity.compareTo(b.popularity))
                      .map((e) => ArgChoiceBuilder(e.displayName.substringSafe(0, 100), e.categoryId.toString()))
                      .toList()
                      .subListSafe(0, 25),
                ),
              ),
            CommandOptionBuilder(
              CommandOptionType.string,
              _groupFilterArg,
              "set group",
              required: true,
            )..registerAutocompleteHandler(
                (event) async => event.respond(
                  (await tcgPlayerService.searchGroups(
                    categoryId: int.parse(event.options.where((element) => element.name == _categoryFilterArg).first.value as String),
                    name: RegExp("${event.focusedOption.value}", caseSensitive: false),
                  ))
                      .toSet()
                      .sorted((b, a) => a.publishedOn.compareTo(b.publishedOn))
                      .map((e) => ArgChoiceBuilder(e.name.substringSafe(0, 100), e.groupId.toString()))
                      .toList()
                      .subListSafe(0, 25),
                ),
              ),
            CommandOptionBuilder(
              CommandOptionType.string,
              _nameArg,
              "search name",
              required: true,
            )..registerAutocompleteHandler(
                (p0) async => p0.respond(
                  (await tcgPlayerService //
                          .searchProducts(
                    groupId: int.parse(p0.options.where((element) => element.name == _groupFilterArg).first.value as String),
                    anyName: RegExp("${RegExp.escape((p0.focusedOption.value as String?) ?? "")}", caseSensitive: false),
                  ))
                      .sorted((a, b) => a.name.compareTo(b.name))
                      .where((e) => e.name.isNotEmpty)
                      .map((e) => ArgChoiceBuilder(e.name.substringSafe(0, 100), e.productId.toString()))
                      .prependedBy([
                        if (p0.focusedOption.value != null && (p0.focusedOption.value as String).isNotEmpty)
                          ArgChoiceBuilder(p0.focusedOption.value as String, p0.focusedOption.value as String)
                      ])
                      .toList()
                      .subListSafe(0, 25),
                ),
              ),
          ],
        ) {
    registerHandler(
      (p0) => _searchHandler(
        context: p0,
        tcgPlayerService: tcgPlayerService,
      ),
    );
  }

  static void _searchHandler({required ISlashCommandInteractionEvent context, required TcgPlayerCachingClient tcgPlayerService}) async {
    await context.acknowledge();

    int groupId = int.parse(context.getArg(_groupFilterArg).value as String);
    String searchString = context.getArg(_nameArg).value as String;
    int? productId = int.tryParse(searchString);
    RegExp searchRegex = RegExp(RegExp.escape(searchString), caseSensitive: false);

    List<ProductModel> products;

    if (productId != null) {
      products = (await tcgPlayerService.searchProducts(
        groupId: groupId,
        productId: productId,
      ));
    } else {
      products = (await tcgPlayerService.searchProducts(
        groupId: groupId,
        anyName: searchRegex,
      ));
    }

    Map<int, SkuPriceCache> skuPriceCacheById = await tcgPlayerService.searchSkuPriceCachesBySkuIds(
      skuIds: products.expand((product) => product.skus.map((sku) => sku.skuId)).toList(),
    );

    if (products.isEmpty) {
      await context.respond(MessageBuilder.content("No results for `$searchString!`"));
    } else if (products.length == 1) {
      await context.respond(MessageBuilder.embed(buildProductEmbed(product: products.first, skuPriceCacheById: skuPriceCacheById, botColor: botColor)));
    } else {
      await context.respond(MessageBuilder.content("${products.length} results for `$searchString`!"));

      IMessage originalResponse = await context.getOriginalResponse();
      var channel = await originalResponse.channel.getOrDownload();
      var sendFunction = (MessageBuilder messageBuilder) async => context.sendFollowup(messageBuilder);
      if (channel.channelType != ChannelType.guildPublicThread && channel.channelType != ChannelType.guildPrivateThread) {
        channel = await originalResponse.createAndGetThread(ThreadBuilder("Search: $searchString")..archiveAfter = ThreadArchiveTime.hour);
        sendFunction = channel.sendMessage;
      }

      List<List<EmbedBuilder>> embedChunks = products //
          .map((e) => buildProductEmbed(product: e, skuPriceCacheById: skuPriceCacheById, botColor: botColor))
          .toChunksOfMaxLength();

      for (List<EmbedBuilder> embedChunk in embedChunks) {
        try {
          await sendFunction(MessageBuilder()..embeds = embedChunk);
        } catch (e, stacktrace) {
          //A malformed embed will break the message
          String errorString = "$e\n$stacktrace";
          await sendFunction(MessageBuilder.content(errorString.substring(0, min(errorString.length, 2000))));
          await sendFunction(MessageBuilder.content(embedChunk.map((e) => "${e.title}\n${e.url}\n${e.fields.map((e) => e.content).join("\n")}").join("\n")));
        }
      }
    }
  }

  static EmbedBuilder buildProductEmbed({required ProductModel product, required Map<int, SkuPriceCache> skuPriceCacheById, required DiscordColor? botColor}) {
    printingAbr(Printing printing) {
      List<String> segments = printing.name.split(' ');
      int maxWidth = 4;
      int segmentWidth = max(maxWidth ~/ segments.length, 1);
      return segments.map((segment) => segment.substring(0, min(segmentWidth, segment.length))).join("");
    }

    EmbedBuilder embedBuilder = EmbedBuilder()
      ..color = botColor
      ..addAuthor((author) {
        author.name =
            "${product.group.name}${product.extendedData.where((element) => RegExp("number", caseSensitive: false).hasMatch(element.name)).map((e) => " | ${e.value}").tryFirst(orElse: "")}";
      })
      ..title = "${product.name}"
      ..url = product.url.toDiscordString()
      ..imageUrl = product.imageUrl.toDiscordString()
      ..fields = product.skus
          .sorted((a, b) => -1 * a.printing.displayOrder.compareTo(b.printing.displayOrder))
          .sorted((a, b) => a.condition?.displayOrder.compareTo(b.condition?.displayOrder ?? 0) ?? -1)
          .map((sku) => EmbedFieldBuilder(
                "${sku.condition?.abbreviation} ${printingAbr(sku.printing)}",
                () {
                  const String ws = "\u2800";
                  const String nil = "$ws---";
                  if (skuPriceCacheById.get(sku.skuId)?.skuPrice.lowPrice == null && skuPriceCacheById.get(sku.skuId)?.skuPrice.marketPrice == null) {
                    return null;
                  }
                  return "${MessageDecoration.bold.format("L$ws")}${skuPriceCacheById.get(sku.skuId)?.skuPrice.lowPrice?.toFormat(usdFormat) ?? nil}\n${MessageDecoration.bold.format("M ")}${skuPriceCacheById.get(sku.skuId)?.skuPrice.marketPrice?.toFormat(usdFormat) ?? nil}";
                }(),
                true,
              ))
          .where((element) => element.content != null)
          .toList()
      ..timestamp = skuPriceCacheById.values
          .map((e) => e.timestamp)
          .fold<DateTime>(DateTime.now(), (previousValue, element) => previousValue.isBefore(element) ? previousValue : element)
      ..addFooter((footer) {
        footer.text = product.url.host;
      })
      ..trimToMaxLength();

    return embedBuilder;
  }
}
