import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:logging/logging.dart';

import 'actions/tcgplayer_alert_action_service.dart';
import 'commands/tcgplayer_alert_command.dart';
import 'commands/tcgplayer_group_summary_command.dart';
import 'commands/tcgplayer_search_command.dart';
import 'config/constants.dart';

class CardboardBot {
  static final Logger _logger = Logger("$CardboardBot");

  CardboardBot._();

  static const int intents = GatewayIntents.guildMessages | GatewayIntents.directMessages | GatewayIntents.messageContent;

  static Future<void> boot({
    required INyxxWebsocket bot,
    required IInteractions interactions,
    required List<InclusionRule> tcgplayerInclusionRules,
  }) async {
    TcgPlayerCachingService tcgPlayerService = await TcgPlayerCachingService.initialize(tcgplayerInclusionRules);
    TcgPlayerAlertActionService tcgPlayerAlertActionService = TcgPlayerAlertActionService(bot, tcgPlayerService)..boot();

    _replaceTcgPlayerEmbeds(bot, tcgPlayerService);

    interactions.registerSlashCommand(SlashCommandBuilder(
      "tcgplayer",
      "tcgplayer actions",
      [
        TcgPlayerSearchCommand(tcgPlayerService: tcgPlayerService),
        TcgPlayerAlertCommand(tcgPlayerService: tcgPlayerService, tcgPlayerAlertActionService: tcgPlayerAlertActionService),
        TcgPlayerGroupSummaryCommand(tcgPlayerService: tcgPlayerService),
      ],
    ));
  }

  static void _replaceTcgPlayerEmbeds(INyxxWebsocket bot, TcgPlayerCachingService tcgPlayerService) {
    RegExp regExp = RegExp(r"tcgplayer.com/product/(\d+)", caseSensitive: false);
    bot.eventsWs.onMessageReceived.listen((event) async {
      Match? match = regExp.firstMatch(event.message.content);
      if (match?.group(1) != null) {
        ProductWrapper? productWrapper = tcgPlayerService.searchProductsWrapped(productId: int.parse(match!.group(1)!)).tryFirst();
        if (productWrapper != null) {
          await event.message.suppressEmbeds();
          var skuPriceCacheById = await tcgPlayerService.getSkuPriceCache(skuIds: productWrapper.skus.map((e) => e.skuId).toList());
          await event.message.channel.sendMessage(
            MessageBuilder.embed(TcgPlayerSearchCommand.buildProductEmbed(
              product: productWrapper,
              skuPriceCacheById: skuPriceCacheById,
              botColor: botColor,
            ))
              ..replyBuilder = ReplyBuilder.fromMessage(event.message),
          );
        }
      }
    });
  }
}
