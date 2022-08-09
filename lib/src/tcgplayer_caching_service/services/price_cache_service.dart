import 'dart:async';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/monads.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import '../models/sku_price_cache.dart';

class PriceCacheService {
  // ignore: unused_field
  static final Logger _logger = Logger("$PriceCacheService");

  final Map<int, Expiring<Future<SkuPriceCache>>> _expiringFutureSkuPriceCacheById = {};

  PriceCacheService() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _expiringFutureSkuPriceCacheById.removeWhere((key, value) => value.isExpired());
    });
  }

  Future<Map<int, SkuPriceCache>> getSkuPriceCache({required List<int> skuIds}) async {
    Map<int, Future<SkuPriceCache>> futureSkuPriceCache = {};
    List<int> staleSkuIds = [];

    for (int skuId in skuIds) {
      if (_expiringFutureSkuPriceCacheById.containsKey(skuId)) {
        futureSkuPriceCache[skuId] = _expiringFutureSkuPriceCacheById.get(skuId)!.object;
      } else {
        staleSkuIds.add(skuId);
      }
    }

    futureSkuPriceCache.addAll(_refreshSkuPriceCache(skuIds: staleSkuIds));

    return Map.fromIterables(futureSkuPriceCache.keys, await Future.wait(futureSkuPriceCache.values));
  }

  Map<int, Future<SkuPriceCache>> _refreshSkuPriceCache({required List<int> skuIds}) {
    if (skuIds.isEmpty) return {};

    // Get Expiring Future SkuPriceCache Map
    Map<int, Expiring<Future<SkuPriceCache>>> futureSkuPriceCache = _getApiSkuPrices(skuIds).map(
      (key, value) => MapEntry(
        key,
        Expiring(
            value.then(
              (skuPrice) => SkuPriceCache(timestamp: DateTime.now(), skuPrice: skuPrice),
            ),
            lifespan: const Duration(seconds: 30)),
      ),
    );

    // Set Cache
    _expiringFutureSkuPriceCacheById.addAll(futureSkuPriceCache);

    return futureSkuPriceCache.map((key, value) => MapEntry(key, value.object));
  }

  Map<int, Future<SkuPrice>> _getApiSkuPrices(List<int> skuIds) {
    Map<int, Future<SkuPrice>> allResults = {};
    // Experimentally found near maximum chunk size
    int chunkSize = 250;
    List<List<int>> chunks = skuIds.toChunks(chunkSize);
    for (List<int> chunk in chunks) {
      var completer = Completer<Map<int, SkuPrice>>();
      for (int skuId in chunk) {
        allResults[skuId] = completer.future.then((value) => Future.value(value.get(skuId)));
      }
      completer.complete(ListSkuMarketPrices(skuIds: chunk).get().then((value) => Map.fromIterables(value.results.map((e) => e.skuId), value.results)));
    }
    return allResults;
  }
}
