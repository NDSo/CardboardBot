import 'dart:async';
import 'dart:io';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/src/google_cloud_services/google_cloud_service.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/models/product_local_cache.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import 'models/category_group_cache.dart';
import 'models/inclusion_rule.dart';
import 'models/product_wrapper.dart';
import 'models/sku_price_cache.dart';
import 'models/sku_price_cache_change.dart';
import 'services/category_group_caching_service.dart';

class TcgPlayerCachingClient {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerCachingClient");
  static TcgPlayerCachingClient? _singleton;
  final CategoryGroupCachingService _categoryGroupCachingService;

  CategoryGroupCache get _categoryGroupCache => _categoryGroupCachingService.categoryGroupCache;

  static Future<TcgPlayerCachingClient> initialize(List<InclusionRule> inclusionRules) async {
    if (_singleton != null) {
      _logger.warning("Tried to initialize $TcgPlayerCachingClient more than once!");
      return _singleton!;
    }
    var categoryGroupCachingService = await CategoryGroupCachingService.initialize(inclusionRules);
    _singleton ??= TcgPlayerCachingClient._internal(categoryGroupCachingService);
    await _singleton!._initialize();
    return _singleton!;
  }

  factory TcgPlayerCachingClient() {
    if (_singleton == null) throw Exception("$TcgPlayerCachingClient needs initialized!");
    return _singleton!;
  }

  TcgPlayerCachingClient._internal(this._categoryGroupCachingService);

  // Sku Price Cache
  static const String _priceCachePath = 'cardboard_bot/data/tcgplayer/price_cache.gzip';

  String _productCacheFirestorePath(int groupId) => "productsByGroup/groupId=$groupId";
  static const Duration _priceCacheMaxAge = Duration(hours: 1);
  Map<int, SkuPriceCache> _skuPriceCacheById = {};
  final Map<int, Future<SkuPriceCache>> _futureSkuPriceCacheById = {};
  final StreamController<Map<int, SkuPriceCacheChange>> _skuPriceCacheChangeController = StreamController.broadcast();

  // USER LEVEL QUERY FUNCTIONS
  DateTime get productCacheTimestamp => _categoryGroupCache.timestamp;

  Stream<Map<int, SkuPriceCacheChange>> get onSkuPriceCacheChange => _skuPriceCacheChangeController.stream;
  Timer? _writeToStorageTimer;
  Timer? _clearProductLocalCacheTimer;

  Future<void> _initialize() async {
    await _readPriceCacheFromStorage();

    ProcessSignal processSignal = !Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigint;
    processSignal.watch().listen((event) async {
      await _writePriceCacheToStorage();
    });
    _writeToStorageTimer ??= Timer.periodic(const Duration(hours: 6), (timer) async {
      await _writePriceCacheToStorage();
    });
    _clearProductLocalCacheTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
      _productLocalCacheByGroupId.removeWhere((key, value) => value.isExpired());
    });
  }

  Future<List<ProductWrapper>> wrapProducts(List<ProductExtended> products) async {
    return products.map((e) => ProductWrapper(e, this)).toList();
  }

  bool _match<T>(T? a, bool Function(T a) match) => a == null ? true : match(a);

  bool _matchInt(int? a, int? field) => _match<int>(a, (a) => a == field);

  bool _matchRegex(RegExp? a, String? field) => _match<RegExp>(a, (a) => a.hasMatch(field ?? ""));

  List<Category> searchCategories({int? categoryId, RegExp? anyName, RegExp? name, RegExp? displayName}) {
    return _categoryGroupCache.categoryList
        .where(
          (e) =>
              _matchInt(categoryId, e.categoryId) &&
              _match<RegExp>(anyName, (a) => e.matchAnyName(a)) &&
              _matchRegex(name, e.name) &&
              _matchRegex(displayName, e.displayName),
        )
        .toList();
  }

  List<Group> searchGroups({int? groupId, int? categoryId, RegExp? name}) {
    return _categoryGroupCache.groupList
        .where(
          (e) => _matchInt(groupId, e.groupId) && _matchInt(categoryId, e.categoryId) && _matchRegex(name, e.name),
        )
        .toList();
  }

  Future<List<ProductExtended>> searchProductsBySkuId({required int skuId}) async {
    int groupId = _categoryGroupCache.groupIdByProductId[_categoryGroupCache.productIdBySkuId[skuId]]!;
    return _searchProducts(groupId: groupId, skuId: skuId);
  }

  Future<List<ProductExtended>> searchProductsByProductId({required int productId}) async {
    int groupId = _categoryGroupCache.groupIdByProductId[productId]!;
    return _searchProducts(groupId: groupId, productId: productId);
  }

  Future<List<ProductExtended>> searchProductsByGroupId({required int groupId, RegExp? anyName}) async {
    return _searchProducts(groupId: groupId, anyName: anyName);
  }

  final Map<int, ProductLocalCache> _productLocalCacheByGroupId = {};
  Future<List<ProductExtended>> _searchProducts({int? productId, required int groupId, RegExp? anyName, int? skuId}) async {
    List<ProductExtended> products;
    var localCache = _productLocalCacheByGroupId.get(groupId);
    if (localCache != null && localCache.isFresh()) {
      localCache.resetExpiry();
      products = localCache.products;
    } else {
      products = (await GoogleCloudService().get<List<ProductExtended>>(
          fromJson: (dynamic d) => (d as List).cast<Map<String, dynamic>>().map<ProductExtended>(ProductExtended.fromJson).toList(),
          name: _productCacheFirestorePath(groupId), zip: true));
      _productLocalCacheByGroupId[groupId] = ProductLocalCache(products);
    }

    return products
        .where(
          (e) =>
              // _matchInt(groupId, e.groupId) &&
              _match<RegExp>(anyName, (a) => e.matchAnyName(a)) &&
              _matchInt(productId, e.productId) &&
              _match<int>(skuId, (skuId) => e.skus.any((sku) => sku.skuId == skuId)),
        )
        .toList();
  }

  List<Condition> searchConditions({required int categoryId, int? conditionId}) {
    return (_categoryGroupCache.conditionsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(conditionId, e.conditionId),
        )
        .toList();
  }

  List<Printing> searchPrintings({required int categoryId, int? printingId}) {
    return (_categoryGroupCache.printingsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(printingId, e.printingId),
        )
        .toList();
  }

  List<Rarity> searchRarities({required int categoryId, int? rarityId}) {
    return (_categoryGroupCache.raritiesByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(rarityId, e.rarityId),
        )
        .toList();
  }

  Future<void> _writePriceCacheToStorage() async {
    // var file = File(_priceCachePath);
    // file.createSync(recursive: true);
    // file.writeAsBytesSync(gzip.encode(utf8.encode(_jsonEncoder.convert(_skuPriceCacheById.values.toList()))));
    GoogleCloudService().write(object: _skuPriceCacheById.values.toList(), name: "TcgPlayerPriceCache", zip: true);
  }

  Future<Map<int, SkuPriceCache>> _readPriceCacheFromStorage() async {
    // var file = File(_priceCachePath);
    // if (file.existsSync()) {
    //   var skuPriceCacheList = (jsonDecode(utf8.decode(gzip.decode(await file.readAsBytes()))) as List).map((e) => SkuPriceCache.fromJson(e)).toList();
    //   _skuPriceCacheById = Map.fromIterables(skuPriceCacheList.map((e) => e.skuPrice.skuId), skuPriceCacheList);
    // }
    // return _skuPriceCacheById;
    var skuPriceCacheList =
        await GoogleCloudService().readList<SkuPriceCache>(fromJson: (json) => SkuPriceCache.fromJson(json as Map<String, dynamic>), name: "TcgPlayerSkuPriceCache", zip: true);
    if (skuPriceCacheList != null) _skuPriceCacheById = Map.fromIterables(skuPriceCacheList.map((e) => e.skuPrice.skuId), skuPriceCacheList);
    return _skuPriceCacheById;
  }

  Future<Map<int, SkuPriceCache>> getSkuPriceCache({required List<int> skuIds, Duration maxAge = _priceCacheMaxAge}) async {
    Map<int, SkuPriceCache> freshSkuPriceCache = {};
    Map<int, Future<SkuPriceCache>> futureSkuPriceCache = {};
    List<int> staleSkuIds = [];

    for (int skuId in skuIds) {
      if (_skuPriceCacheById.get(skuId)?.timestamp.isAfter(DateTime.now().subtract(maxAge)) ?? false) {
        freshSkuPriceCache[skuId] = _skuPriceCacheById.get(skuId)!;
      } else if (_futureSkuPriceCacheById.get(skuId) != null) {
        futureSkuPriceCache[skuId] = _futureSkuPriceCacheById.get(skuId)!;
      } else {
        staleSkuIds.add(skuId);
      }
    }

    return {
      ...freshSkuPriceCache,
      ...(await _refreshSkuPriceCache(skuIds: staleSkuIds)),
      ...Map.fromIterables(futureSkuPriceCache.keys, await Future.wait(futureSkuPriceCache.values)),
    };
  }

  Future<Map<int, SkuPriceCache>> _refreshSkuPriceCache({required List<int> skuIds}) async {
    if (skuIds.isEmpty) return {};

    // Get Future SkuPriceCache Map
    Map<int, Future<SkuPriceCache>> skuPriceCacheFutureById = _getApiSkuPrices(skuIds).map(
      (key, value) => MapEntry(
        key,
        value.then(
          (skuPrice) => SkuPriceCache(timestamp: DateTime.now(), skuPrice: skuPrice),
        ),
      ),
    );

    // Add in flight request to Future cache, and remove them when they complete
    _futureSkuPriceCacheById.addAll(skuPriceCacheFutureById);
    for (var entry in skuPriceCacheFutureById.entries) {
      entry.value.whenComplete(() => _futureSkuPriceCacheById.remove(entry.key));
    }

    Map<int, SkuPriceCacheChange> skuPriceCacheChangeById = {};
    Map<int, SkuPriceCache> skuPriceCacheById = {};

    for (var skuPriceCache in await Future.wait(skuPriceCacheFutureById.values)) {
      skuPriceCacheChangeById[skuPriceCache.skuPrice.skuId] =
          SkuPriceCacheChange(before: _skuPriceCacheById[skuPriceCache.skuPrice.skuId], after: skuPriceCache);
      skuPriceCacheById[skuPriceCache.skuPrice.skuId] = skuPriceCache;
    }

    _skuPriceCacheChangeController.add(skuPriceCacheChangeById);

    _skuPriceCacheById.addAll(skuPriceCacheById);
    return skuPriceCacheById;
  }

  static Map<int, Future<SkuPrice>> _getApiSkuPrices(List<int> skuIds) {
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
