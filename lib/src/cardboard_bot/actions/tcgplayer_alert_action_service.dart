import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/nyxx_bot_actions.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';

import '../config/constants.dart';
import 'tcgplayer_alert_action.dart';

class TcgPlayerAlertActionService extends ActionService<TcgPlayerAlertAction> {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerAlertActionService");
  final TcgPlayerCachingService _tcgPlayerService;
  Timer? _timer;
  StreamSubscription<Map<int, SkuPriceCacheChange>>? _changeSubscription;

  final _SkuIdQueue _skuIdSet = _SkuIdQueue();

  TcgPlayerAlertActionService(INyxxWebsocket bot, this._tcgPlayerService) : super(bot) {
    setupTimerLoop(Duration.zero);
    setupSkuPriceChangeListener();
  }

  void setupTimerLoop(Duration queryLatency) {
    const int count = 250;
    const Duration desiredMaxAge = Duration(minutes: 3);
    const Duration minimumLatency = Duration(milliseconds: 200);

    Duration intendedLatency = Duration(milliseconds: (desiredMaxAge.inMilliseconds / max((_skuIdSet.length / count), 1)).ceil());
    if (intendedLatency < minimumLatency) intendedLatency = minimumLatency;
    intendedLatency -= queryLatency;
    if (intendedLatency.isNegative) intendedLatency = Duration.zero;

    _timer = Timer(intendedLatency, () async {
      var stopwatch = Stopwatch()..start();
      try {
        var skuIds = _skuIdSet.getNextSkuIds(count: 250).toList();
        await _tcgPlayerService.getSkuPriceCache(skuIds: skuIds, maxAge: desiredMaxAge ~/ 2);
      } finally {
        stopwatch.stop();
        setupTimerLoop(stopwatch.elapsed);
      }
    });
  }

  void setupSkuPriceChangeListener() {
    _changeSubscription = _tcgPlayerService.onSkuPriceCacheChange.listen((skuPriceChanges) async {
      Map<Snowflake, Map<TcgPlayerAlertAction, SkuPriceCacheChange>> skuPriceChangeByAlertByOwnerId = {};
      for (var entry in skuPriceChanges.entries) {
        var alerts = _skuIdSet.getAlertsBySkuId(entry.key).where((alertAction) {
          return ((entry.value.after.skuPrice.lowestListingPrice ?? double.infinity) < (entry.value.before?.skuPrice.lowestListingPrice ?? double.infinity)) &&
              ((entry.value.after.skuPrice.lowestListingPrice ?? double.infinity) <= (alertAction.maxPrice ?? double.infinity));
        }).toList();

        for (var alert in alerts) {
          skuPriceChangeByAlertByOwnerId.update(alert.ownerId, (value) => value..addAll({alert: entry.value}), ifAbsent: () => {alert: entry.value});
        }
      }

      for (var ownerIdAndSkuPriceChangeByAlert in skuPriceChangeByAlertByOwnerId.entries) {
        var message = MessageBuilder();
        message.embeds = ownerIdAndSkuPriceChangeByAlert.value.entries.map((alertAndSkuPriceChange) {
          return _buildProductEmbed(
            product: _tcgPlayerService.searchProductsWrapped(skuId: alertAndSkuPriceChange.key.skuId).tryFirst()!,
            maxPrice: alertAndSkuPriceChange.key.maxPrice,
            skuPriceChange: alertAndSkuPriceChange.value,
            botColor: botColor,
          );
        }).toList();

        (await bot.fetchUser(ownerIdAndSkuPriceChangeByAlert.key)).sendMessage(message);
      }
    });
  }

  EmbedBuilder _buildProductEmbed(
      {required ProductWrapper product, required SkuPriceCacheChange skuPriceChange, required num? maxPrice, required DiscordColor? botColor}) {
    SkuWrapper sku = product.skus.firstWhere((element) => element.skuId == skuPriceChange.after.skuPrice.skuId);

    EmbedBuilder embedBuilder = EmbedBuilder()
      ..color = botColor
      ..addAuthor((author) {
        author.name =
            "${product.group.name}${product.extendedData.where((element) => RegExp("number", caseSensitive: false).hasMatch(element.name)).map((e) => " | ${e.value}").tryFirst(orElse: "")}";
      })
      ..title = "${product.name}"
      ..url = product.url.toDiscordString()
      ..imageUrl = product.imageUrl.toDiscordString()
      ..description = MessageDecoration.bold.format("${sku.condition.name}\n${sku.printing.name}")
      ..fields = [
        EmbedFieldBuilder(
          "Lowest Listing",
          "${skuPriceChange.after.skuPrice.lowPrice?.toFormat(usdFormat)}\n${MessageDecoration.strike.format("${skuPriceChange.before?.skuPrice.lowPrice?.toFormat(usdFormat)}")}",
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

  @override
  TcgPlayerAlertAction actionFromJson(Map<String, dynamic> json) {
    return TcgPlayerAlertAction.fromJson(json);
  }

  @override
  String getName() => "tcgplayer_alert";

  @override
  void bootAction(TcgPlayerAlertAction? action) {
    if (action == null) return;
    _skuIdSet.addAlert(action);
  }

  @override
  void shutdownAction(TcgPlayerAlertAction? action) {
    if (action == null) return;
    _skuIdSet.removeAlert(action);
  }
}

class _SkuIdQueue {
  final Map<int, Set<TcgPlayerAlertAction>> _alertActionBySkuId = {};
  final LinkedHashSet<int> _skuIdSet = LinkedHashSet.identity();

  int get length => _skuIdSet.length;

  int _position = 0;

  Set<int> getNextSkuIds({required int count}) {
    if (count >= _skuIdSet.length) {
      _position = 0;
      return {..._skuIdSet};
    }

    var set = _skuIdSet.skip(_position).take(count).toSet();
    _position += count;

    int wrapCount = count - set.length;
    if (wrapCount > 0) {
      set.addAll(_skuIdSet.skip(0).take(wrapCount));
      _position = wrapCount;
    }

    return set;
  }

  Set<TcgPlayerAlertAction> getAlertsBySkuId(int skuId) => _alertActionBySkuId[skuId] ?? {};

  void addAlert(TcgPlayerAlertAction action) {
    _alertActionBySkuId.update(
      action.skuId,
      (value) => value..add(action),
      ifAbsent: () => {action},
    );
    _skuIdSet.add(action.skuId);
  }

  void removeAlert(TcgPlayerAlertAction action) {
    _alertActionBySkuId.update(
      action.skuId,
      (value) => value..remove(action),
      ifAbsent: () => {},
    );
    if (_alertActionBySkuId[action.skuId]?.isEmpty ?? true) {
      _alertActionBySkuId.remove(action.skuId);
      _skuIdSet.remove(action.skuId);
    }
  }
}
