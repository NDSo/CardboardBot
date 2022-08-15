import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../actions/tcgplayer_alert_action/tcgplayer_alert_action.dart';
import '../actions/tcgplayer_alert_action/tcgplayer_alert_action_service.dart';

class TcgPlayerAlertCommand extends CommandOptionBuilder {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerAlertCommand");
  static const String _categoryArg = "category";
  static const String _groupArg = "group";
  static const String _skuArg = "product";
  static const String _priceArg = "price";

  TcgPlayerAlertCommand({required TcgPlayerCachingClient tcgPlayerService, required TcgPlayerAlertActionService tcgPlayerAlertActionService})
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

  static Future<void> _alertAddAutoCompleteHandler({required IAutocompleteInteractionEvent event, required TcgPlayerCachingClient tcgPlayerService}) async {
    switch (event.focusedOption.name) {
      case _categoryArg:
        return event.respond(
          (await tcgPlayerService.searchCategories(anyName: RegExp("${event.focusedOption.value}", caseSensitive: false)))
              .toSet()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((b, a) => a.popularity.compareTo(b.popularity))
              .map((e) => ArgChoiceBuilder(e.displayName.substringSafe(0, 100), e.categoryId.toString()))
              .toList()
              .subListSafe(0, 25),
        );
      case _groupArg:
        return event.respond(
          (await tcgPlayerService.searchGroups(
            categoryId: int.parse(event.options.where((element) => element.name == _categoryArg).first.value as String),
            name: RegExp("${event.focusedOption.value}", caseSensitive: false),
          ))
              .toSet()
              .sorted((b, a) => a.publishedOn.compareTo(b.publishedOn))
              .map((e) => ArgChoiceBuilder(e.name.substringSafe(0, 100), e.groupId.toString()))
              .toList()
              .subListSafe(0, 25),
        );
      case _skuArg:
        var options = (await tcgPlayerService //
                .searchProducts(
          groupId: int.parse(event.options.where((element) => element.name == _groupArg).first.value as String),
          anyName: RegExp("^${event.focusedOption.value}.*", caseSensitive: false),
        ))
            .sorted((a, b) => a.name.compareTo(b.name))
            .expand(
              (product) => product.skus.map((sku) {
                return ArgChoiceBuilder("${product.name} | ${sku.printing.name} | ${sku.condition?.name}".substringSafe(0, 100), sku.skuId.toString());
              }),
            )
            .toList()
            .subListSafe(0, 25);
        return event.respond(options);
    }
  }

  static Future<void> _alertDeleteAutoCompleteHandler(
      {required IAutocompleteInteractionEvent event,
      required TcgPlayerCachingClient tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    switch (event.focusedOption.name) {
      case _skuArg:
        return event.respond(
          (await tcgPlayerAlertActionService.getActions(ownerId: event.interaction.userAuthor!.id).map((action) async {
            var product = (await tcgPlayerService.searchProductsByProductId(productId: action.productId)).first;
            var sku = product.skus.firstWhere((element) => element.skuId == action.skuId);
            return ArgChoiceBuilder(
                "${product.name} | ${sku.printing.name} | ${sku.condition?.name}${action.maxPrice == null ? "" : " | ${action.maxPrice?.toFormat(usdFormat)}"}"
                    .substringSafe(0, 100),
                action.getId());
          }).waitAll())
              .toList()
              .sorted((a, b) => a.name.compareTo(b.name))
              .sorted((a, b) => a.name.length.compareTo(b.name.length))
              .subListSafe(0, 25),
        );
    }
  }

  static Future<void> _alertAddHandler(
      {required ISlashCommandInteractionEvent context,
      required TcgPlayerCachingClient tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    await context.acknowledge(hidden: true);

    // Limit action count per user
    if (tcgPlayerAlertActionService.isOverLimit(context.interaction.userAuthor!.id)) {
      await context.respond(
        MessageBuilder.content(
            "You've already reached your price alert limit of ${MessageDecoration.bold.format(TcgPlayerAlertActionService.perUserActionLimit.toString())}! Delete one and try again!"),
        hidden: true,
      );
      return;
    }

    int groupId = int.parse(context.getArg(_groupArg).value as String);
    int skuId = int.parse(context.getArg(_skuArg).value as String);
    num maxPrice = context.getArg(_priceArg).value as num;

    var product = (await tcgPlayerService.searchProducts(groupId: groupId, skuId: skuId)).first;
    tcgPlayerAlertActionService.upsert(TcgPlayerAlertAction.create(
      ownerId: context.interaction.userAuthor!.id,
      skuId: skuId,
      productId: product.productId,
      groupId: product.groupId,
      categoryId: product.categoryId,
      maxPrice: maxPrice,
    ));
    var sku = product.skus.firstWhere((element) => element.skuId == skuId);
    String target = "${product.name} | ${sku.printing.name} | ${sku.condition?.name}";
    await context.respond(
      MessageBuilder.content("Alerting for ${MessageDecoration.bold.format(maxPrice.toFormat(usdFormat))} ${MessageDecoration.codeSimple.format(target)}!"),
      hidden: true,
    );
  }

  static void _alertDeleteHandler(
      {required ISlashCommandInteractionEvent context,
      required TcgPlayerCachingClient tcgPlayerService,
      required TcgPlayerAlertActionService tcgPlayerAlertActionService}) async {
    await context.acknowledge(hidden: true);
    String actionId = context.getArg(_skuArg).value as String;
    Snowflake ownerId = context.interaction.userAuthor!.id;

    await tcgPlayerAlertActionService.delete(ownerId, actionId);
    await context.respond(MessageBuilder.content(MessageDecoration.bold.format("Alert successfully deleted!")), hidden: true);
  }
}
