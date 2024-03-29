import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'actions/tcgplayer_alert_action/tcgplayer_alert_action_service.dart';
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
    required TcgPlayerCachingClient tcgPlayerService,
    required TcgPlayerAlertActionService tcgPlayerAlertActionService,
  }) async {
    await _replaceTcgPlayerEmbeds(bot, tcgPlayerService);

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

  static Future<void> _replaceTcgPlayerEmbeds(INyxxWebsocket bot, TcgPlayerCachingClient tcgPlayerService) async {
    RegExp regExp = RegExp(r"tcgplayer.com/product/(\d+)", caseSensitive: false);
    bot.eventsWs.onMessageReceived.listen((event) async {
      Match? match = regExp.firstMatch(event.message.content);
      if (match?.group(1) != null) {
        ProductModel? product = (await tcgPlayerService.searchProductsByProductId(productId: int.parse(match!.group(1)!))).tryFirst();
        if (product != null) {
          await event.message.suppressEmbeds();
          var skuPriceCacheById = await tcgPlayerService.searchSkuPriceCachesBySkuIds(skuIds: product.skus.map((e) => e.skuId).toList());
          await event.message.channel.sendMessage(
            MessageBuilder.embed(TcgPlayerSearchCommand.buildProductEmbed(
              product: product,
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
