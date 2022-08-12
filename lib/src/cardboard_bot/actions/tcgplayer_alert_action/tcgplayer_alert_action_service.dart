import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/nyxx_bot_actions.dart';
import 'package:cardboard_bot/repository.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';

import '../../config/constants.dart';
import 'tcgplayer_alert_action.dart';

class TcgPlayerAlertActionService extends ActionService<TcgPlayerAlertAction> {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerAlertActionService");
  final TcgPlayerCachingClient _tcgPlayerService;

  final Map<int, SkuPriceCache> _previousSkuPrices = {};
  final Repository<SkuPriceCache> _previousSkuPriceStorageRepository;

  final _SkuIdQueue _skuIdSet = _SkuIdQueue();

  TcgPlayerAlertActionService(super.bot, super._actionRepository, this._tcgPlayerService, this._previousSkuPriceStorageRepository) {
    setupPriceCheckLoop(Duration.zero);
    Timer.periodic(const Duration(hours: 1), (timer) async {
      if (_previousSkuPrices.isNotEmpty) {
        await _previousSkuPriceStorageRepository.upsert(
          ids: _previousSkuPrices.keys.map((e) => e.toString()).toList(), objects: _previousSkuPrices.values.toList());
      }
    });
  }

  void setupPriceCheckLoop(Duration queryLatency) {
    const int count = 250;
    const Duration desiredMaxAge = Duration(minutes: 3);
    const Duration minimumLatency = Duration(milliseconds: 200);

    Duration intendedLatency = Duration(milliseconds: (desiredMaxAge.inMilliseconds / max((_skuIdSet.length / count), 1)).ceil());
    if (intendedLatency < minimumLatency) intendedLatency = minimumLatency;
    intendedLatency -= queryLatency;
    if (intendedLatency.isNegative) intendedLatency = Duration.zero;

    Timer(intendedLatency, () async {
      var stopwatch = Stopwatch()..start();
      try {
        var skuIds = _skuIdSet.getNextSkuIds(count: 250).toList();
        await _checkSkuPriceCacheChange(await _tcgPlayerService.searchSkuPriceCachesBySkuIds(skuIds: skuIds));
      } catch (e, stacktrace) {
        _logger.severe("Failed to check for sku price changes!", e, stacktrace);
      } finally {
        stopwatch.stop();
        setupPriceCheckLoop(stopwatch.elapsed);
      }
    });
  }

  Future<void> _checkSkuPriceCacheChange(Map<int, SkuPriceCache> skuPriceCache) async {
    // Initial load from storage to reduce noise on startup
    if (_previousSkuPrices.isEmpty && skuPriceCache.isNotEmpty) {
      _previousSkuPrices.addAll({
        for (var skuPriceCache in await _previousSkuPriceStorageRepository.getAll()) skuPriceCache.skuPrice.skuId: skuPriceCache,
      });
    }

    // Build Changes
    var skuPriceChanges = skuPriceCache.map<int, _SkuPriceCacheChange>(
      (key, value) => MapEntry(
        key,
        _SkuPriceCacheChange(
          before: _previousSkuPrices[key],
          after: value,
        ),
      ),
    );

    // Update Previous
    _previousSkuPrices.addAll(skuPriceCache);

    Map<Snowflake, Map<TcgPlayerAlertAction, _SkuPriceCacheChange>> skuPriceChangeByAlertByOwnerId = {};
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
      message.embeds = (await ownerIdAndSkuPriceChangeByAlert.value.entries.map((alertAndSkuPriceChange) async {
        return _buildProductEmbed(
          product: (await _tcgPlayerService.searchProductsByProductId(productId: alertAndSkuPriceChange.key.productId)).first,
          maxPrice: alertAndSkuPriceChange.key.maxPrice,
          skuPriceChange: alertAndSkuPriceChange.value,
          botColor: botColor,
        );
      }).waitAll())
          .toList();

      (await bot.fetchUser(ownerIdAndSkuPriceChangeByAlert.key)).sendMessage(message);
    }
  }

  EmbedBuilder _buildProductEmbed(
      {required ProductModel product, required _SkuPriceCacheChange skuPriceChange, required num? maxPrice, required DiscordColor? botColor}) {
    SkuModel sku = product.skus.firstWhere((element) => element.skuId == skuPriceChange.after.skuPrice.skuId);

    EmbedBuilder embedBuilder = EmbedBuilder()
      ..color = botColor
      ..addAuthor((author) {
        author.name =
            "${product.group.name}${product.extendedData.where((element) => RegExp("number", caseSensitive: false).hasMatch(element.name)).map((e) => " | ${e.value}").tryFirst(orElse: "")}";
      })
      ..title = "${product.name}"
      ..url = product.url.toDiscordString()
      ..imageUrl = product.imageUrl.toDiscordString()
      ..description = MessageDecoration.bold.format("${sku.condition?.name}\n${sku.printing.name}")
      ..fields = [
        EmbedFieldBuilder(
          "Lowest Listing",
          "${skuPriceChange.after.skuPrice.lowestListingPrice?.toFormat(usdFormat)}\n${MessageDecoration.strike.format("${skuPriceChange.before?.skuPrice.lowestListingPrice?.toFormat(usdFormat)}")}",
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

class _SkuPriceCacheChange {
  SkuPriceCache? before;
  SkuPriceCache after;

  _SkuPriceCacheChange({required this.before, required this.after});
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
