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
  static const String _categoryFilterArg = "category";

  TcgPlayerSearchCommand({required TcgPlayerCachingService tcgPlayerService})
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
                (p0) => p0.respond(
                  tcgPlayerService //
                      .searchCategories(anyName: RegExp(p0.focusedOption.value as String, caseSensitive: false))
                      .map((e) => e.displayName.substringSafe(0, 100))
                      .toSet()
                      .map((e) => ArgChoiceBuilder(e, e))
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
                (p0) => p0.respond(
                  tcgPlayerService //
                      .searchProducts(
                        categoryId: tcgPlayerService
                            .searchCategories(
                              displayName: RegExp(
                                p0.options
                                    .firstWhere(
                                      (element) => element.name == _categoryFilterArg,
                                    )
                                    .value as String,
                                caseSensitive: false,
                              ),
                            )
                            .tryFirst()
                            ?.categoryId,
                        anyName: RegExp(".*${p0.focusedOption.value}.*", caseSensitive: false),
                      )
                      .map((e) => e.name)
                      .toSet()
                      .toList()
                      .sorted((a, b) => a.compareTo(b))
                      .sorted((a, b) => a.length.compareTo(b.length))
                      .prependedBy([p0.focusedOption.value ?? ""])
                      .where((e) => e.isNotEmpty)
                      .map((e) => e.substringSafe(0, 100))
                      .map((name) => ArgChoiceBuilder(name, name))
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

  static void _searchHandler({required ISlashCommandInteractionEvent context, required TcgPlayerCachingService tcgPlayerService}) async {
    await context.acknowledge();

    String categoryString = context.getArg(_categoryFilterArg).value;
    String searchString = context.getArg(_nameArg).value;
    RegExp searchRegex = RegExp(searchString, caseSensitive: false);

    List<ProductWrapper> products = tcgPlayerService //
        .searchProductsWrapped(
          categoryId: tcgPlayerService //
              .searchCategories(name: RegExp(RegExp.escape(categoryString)))
              .tryFirst()
              ?.categoryId,
          anyName: searchRegex,
        )
        .sorted((a, b) => -1 * a.group.publishedOn.compareTo(b.group.publishedOn));

    Map<int, SkuPriceCache> skuPriceCacheById = await tcgPlayerService.getSkuPriceCache(
      skuIds: products.expand((product) => product.skus.map((sku) => sku.skuId)).toList(),
      maxAge: Duration(minutes: 5),
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

  static EmbedBuilder buildProductEmbed({required ProductWrapper product, required Map<int, SkuPriceCache> skuPriceCacheById, required DiscordColor? botColor}) {
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
          .sorted((a, b) => a.condition.displayOrder.compareTo(b.condition.displayOrder))
          .map((sku) => EmbedFieldBuilder(
                "${sku.condition.abbreviation} ${printingAbr(sku.printing)}",
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
