import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:logging/logging.dart';
import 'package:cardboard_bot/extensions.dart';

import '../actions/tcgplayer_alert_action.dart';
import '../actions/tcgplayer_alert_action_service.dart';
import '../config/constants.dart';

class TcgPlayerAlertCommand extends CommandOptionBuilder {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerAlertCommand");
  static const String _categoryArg = "category";
  static const String _groupArg = "group";
  static const String _skuArg = "product";
  static const String _priceArg = "price";

  TcgPlayerAlertCommand({required TcgPlayerCachingService tcgPlayerService, required TcgPlayerAlertActionService tcgPlayerAlertActionService})
      : super(
          CommandOptionType.subCommandGroup,
          "alert",
          "manage price alerts",
          options: [
            CommandOptionBuilder(
              CommandOptionType.subCommand,
              "add",
              "setup price alert",
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
                CommandOptionBuilder(
                  CommandOptionType.string,
                  _skuArg,
                  "product name",
                  required: true,
                )..registerAutocompleteHandler((p0) => _alertAddAutoCompleteHandler(event: p0, tcgPlayerService: tcgPlayerService)),
                CommandOptionBuilder(
                  CommandOptionType.number,
                  _priceArg,
                  "max price",
                  required: true,
                ),
              ],
            )..registerHandler(
                (p0) => _alertAddHandler(context: p0, tcgPlayerService: tcgPlayerService, tcgPlayerAlertActionService: tcgPlayerAlertActionService)),
            CommandOptionBuilder(
              CommandOptionType.subCommand,
              "delete",
              "delete price alert",
              options: [
                CommandOptionBuilder(
                  CommandOptionType.string,
                  _skuArg,
                  "product name",
                  required: true,
                )..registerAutocompleteHandler((p0) =>
                    _alertDeleteAutoCompleteHandler(event: p0, tcgPlayerService: tcgPlayerService, tcgPlayerAlertActionService: tcgPlayerAlertActionService)),
              ],
            )..registerHandler(
                (p0) => _alertDeleteHandler(context: p0, tcgPlayerService: tcgPlayerService, tcgPlayerAlertActionService: tcgPlayerAlertActionService))
          ],
        );

  static Future<void> _alertAddAutoCompleteHandler({required IAutocompleteInteractionEvent event, required TcgPlayerCachingService tcgPlayerService}) async {
    switch (event.focusedOption.name) {
      case _categoryArg:
        return event.respond(
          tcgPlayerService
              .searchCategories(anyName: RegExp("${event.focusedOption.value}", caseSensitive: false))
              .toSet()
              .map((e) => ArgChoiceBuilder(e.displayName.substringSafe(0, 100), e.categoryId.toString()))
              .toList()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((a, b) => a.name.length.compareTo(b.name.length))
              .subListSafe(0, 25),
        );
      case _groupArg:
        return event.respond(
          tcgPlayerService
              .searchGroups(
                categoryId: int.parse(event.options.where((element) => element.name == _categoryArg).first.value),
                name: RegExp("${event.focusedOption.value}", caseSensitive: false),
              )
              .toSet()
              .map((e) => ArgChoiceBuilder(e.name.substringSafe(0, 100), e.groupId.toString()))
              .toList()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((a, b) => a.name.length.compareTo(b.name.length))
              .subListSafe(0, 25),
        );
      case _skuArg:
        var options = tcgPlayerService //
            .searchProducts(
              categoryId: int.parse(event.options.where((element) => element.name == _categoryArg).first.value),
              groupId: int.parse(event.options.where((element) => element.name == _groupArg).first.value),
              anyName: RegExp("^${event.focusedOption.value}.*", caseSensitive: false),
            )
            .sorted((a, b) => a.name.compareTo(b.name))
            .sorted((a, b) => a.name.length.compareTo(b.name.length))
            .expand(
              (product) => product.skus.map((sku) {
                Printing printing = tcgPlayerService.searchPrintings(categoryId: product.categoryId, printingId: sku.printingId).first;
                Condition condition = tcgPlayerService.searchConditions(categoryId: product.categoryId, conditionId: sku.conditionId).first;
                return ArgChoiceBuilder("${product.name} | ${printing.name} | ${condition.name}".substringSafe(0, 100), sku.skuId.toString());
              }),
            )
            .toList()
            .subListSafe(0, 25);
        return event.respond(options);
    }
  }

  static Future<void> _alertDeleteAutoCompleteHandler(
      {required IAutocompleteInteractionEvent event,
      required TcgPlayerCachingService tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    switch (event.focusedOption.name) {
      case _skuArg:
        return event.respond(
          tcgPlayerAlertActionService
              .getActions(ownerId: event.interaction.userAuthor!.id)
              .map((action) {
                ProductExtended product = tcgPlayerService.searchProducts(skuId: action.skuId).first;
                Sku sku = product.skus.firstWhere((element) => element.skuId == action.skuId);
                Printing printing = tcgPlayerService.searchPrintings(categoryId: product.categoryId, printingId: sku.printingId).first;
                Condition condition = tcgPlayerService.searchConditions(categoryId: product.categoryId, conditionId: sku.conditionId).first;
                return ArgChoiceBuilder("${product.name} | ${printing.name} | ${condition.name}".substringSafe(0, 100), action.getId());
              })
              .toList()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((a, b) => a.name.length.compareTo(b.name.length))
              .subListSafe(0, 25),
        );
    }
  }

  static Future<void> _alertAddHandler(
      {required ISlashCommandInteractionEvent context,
      required TcgPlayerCachingService tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    await context.acknowledge(hidden: true);
    int skuId = int.parse(context.getArg(_skuArg).value);
    num maxPrice = context.getArg(_priceArg).value;

    tcgPlayerAlertActionService.upsert(TcgPlayerAlertAction.create(
      ownerId: context.interaction.userAuthor!.id,
      skuId: skuId,
      maxPrice: maxPrice,
    ));
    ProductWrapper productWrapper = tcgPlayerService.searchProductsWrapped(skuId: skuId).first;
    SkuWrapper skuWrapper = productWrapper.skus.firstWhere((element) => element.skuId == skuId);
    String target = "${productWrapper.name} | ${skuWrapper.printing.name} | ${skuWrapper.condition.name}";
    await context.respond(
        MessageBuilder.content("Alerting for ${MessageDecoration.bold.format(maxPrice.toFormat(usdFormat))} ${MessageDecoration.codeSimple.format(target)}!"),
        hidden: true);
  }

  static void _alertDeleteHandler(
      {required ISlashCommandInteractionEvent context,
      required TcgPlayerCachingService tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    await context.acknowledge(hidden: true);
    String actionId = context.getArg(_skuArg).value;
    Snowflake ownerId = context.interaction.userAuthor!.id;

    await tcgPlayerAlertActionService.delete(ownerId, actionId);
    await context.respond(MessageBuilder.content(MessageDecoration.bold.format("Alert successfully deleted!")), hidden: true);
  }
}
