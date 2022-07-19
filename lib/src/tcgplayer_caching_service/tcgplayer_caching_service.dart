import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import 'models/inclusion_rule.dart';
import 'models/product_cache.dart';
import 'models/product_wrapper.dart';
import 'models/sku_price_cache.dart';
import 'models/sku_price_cache_change.dart';

class TcgPlayerCachingService {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerCachingService");
  static TcgPlayerCachingService? _singleton;

  static Future<TcgPlayerCachingService> initialize(List<InclusionRule> inclusionRules) async {
    if (_singleton != null) {
      _logger.warning("Tried to initialize $TcgPlayerCachingService more than once!");
      return _singleton!;
    }
    _singleton ??= TcgPlayerCachingService._internal(inclusionRules: inclusionRules);
    await _singleton!._initialize();
    return _singleton!;
  }

  factory TcgPlayerCachingService() {
    if (_singleton == null) throw Exception("$TcgPlayerCachingService needs initialized!");
    return _singleton!;
  }

  TcgPlayerCachingService._internal({required this.inclusionRules});

  //Caching Logic
  List<InclusionRule> inclusionRules;

  final JsonEncoder _jsonEncoder = JsonEncoder();
  static const String _productCachePath = 'data/tcgplayer/product_cache.gzip';
  static const String _priceCachePath = 'data/tcgplayer/price_cache.gzip';
  static const Duration _priceCacheMaxAge = Duration(hours: 1);

  Timer? _refreshProductCacheTimer;
  Timer? _writeToStorageTimer;

  ProductCache _productCache = ProductCache.empty();
  Future<ProductCache>? _futureProductCache;
  Map<int, SkuPriceCache> _skuPriceCacheById = {};
  final Map<int, Future<SkuPriceCache>> _futureSkuPriceCacheById = {};

  // SkuPrice Change Logic
  final StreamController<Map<int, SkuPriceCacheChange>> _skuPriceCacheChangeController = StreamController.broadcast();

  // USER LEVEL QUERY FUNCTIONS
  DateTime get productCacheTimestamp => _productCache.timestamp;

  Stream<Map<int, SkuPriceCacheChange>> get onSkuPriceCacheChange => _skuPriceCacheChangeController.stream;

  Future<ProductCache> get freshProductCache => _futureProductCache ?? Future.value(_productCache);

  List<ProductWrapper> searchProductsWrapped({int? productId, int? groupId, int? categoryId, RegExp? anyName, int? skuId}) {
    return searchProducts(productId: productId, groupId: groupId, categoryId: categoryId, anyName: anyName, skuId: skuId)
        .map((e) => ProductWrapper(e, this))
        .toList();
  }

  bool _match<T>(T? a, bool Function(T a) match) => a == null ? true : match(a);

  bool _matchInt(int? a, int? field) => _match<int>(a, (a) => a == field);

  bool _matchRegex(RegExp? a, String? field) => _match<RegExp>(a, (a) => a.hasMatch(field ?? ""));

  List<Category> searchCategories({int? categoryId, RegExp? anyName, RegExp? name, RegExp? displayName}) {
    return _productCache.categoryList
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
    return _productCache.groupList
        .where(
          (e) => _matchInt(groupId, e.groupId) && _matchInt(categoryId, e.categoryId) && _matchRegex(name, e.name),
        )
        .toList();
  }

  List<ProductExtended> searchProducts({int? productId, int? groupId, int? categoryId, RegExp? anyName, int? skuId}) {
    return _productCache.productList
        .where(
          (e) =>
              _matchInt(categoryId, e.categoryId) &&
              _matchInt(groupId, e.groupId) &&
              _match<RegExp>(anyName, (a) => e.matchAnyName(a)) &&
              _matchInt(productId, e.productId) &&
              _match<int>(skuId, (skuId) => e.skus.any((sku) => sku.skuId == skuId)),
        )
        .toList();
  }

  List<Condition> searchConditions({required int categoryId, int? conditionId}) {
    return (_productCache.conditionsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(conditionId, e.conditionId),
        )
        .toList();
  }

  List<Printing> searchPrintings({required int categoryId, int? printingId}) {
    return (_productCache.printingsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(printingId, e.printingId),
        )
        .toList();
  }

  List<Rarity> searchRarities({required int categoryId, int? rarityId}) {
    return (_productCache.raritiesByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(rarityId, e.rarityId),
        )
        .toList();
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

  Future<void> _initialize() async {
    await _readProductCacheFromStorage();
    await _readPriceCacheFromStorage();
    await _setupRefresh();

    void writeToStorage() {
      _writeProductCacheToStorage(_productCache);
      _writePriceCacheToStorage(_skuPriceCacheById.values.toList());
    }

    ProcessSignal processSignal = !Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigint;
    processSignal.watch().listen((event) {
      writeToStorage();
    });
    _writeToStorageTimer ??= Timer.periodic(Duration(hours: 6), (timer) {
      writeToStorage();
    });
  }

  Future<void> _setupRefresh() async {
    refreshProductFunc() async {
      return await _refreshProductCache();
    }

    // Run Now
    if (DateTime.now().toUtc().isAfter(_productCache.timestamp.add(Duration(hours: 12)))) {
      refreshProductFunc();
    }

    // Run Timers
    _refreshProductCacheTimer?.cancel();
    _refreshProductCacheTimer = Timer.periodic(Duration(hours: 12), (timer) => refreshProductFunc());
  }

  void _writeProductCacheToStorage(ProductCache productCache) {
    var file = File(_productCachePath);
    file.createSync(recursive: true);
    file.writeAsBytesSync(gzip.encode(utf8.encode(_jsonEncoder.convert(_productCache))));
  }

  void _writePriceCacheToStorage(List<SkuPriceCache> skuPriceCacheList) {
    var file = File(_priceCachePath);
    file.createSync(recursive: true);
    file.writeAsBytesSync(gzip.encode(utf8.encode(_jsonEncoder.convert(_skuPriceCacheById.values.toList()))));
  }

  Future<ProductCache> _readProductCacheFromStorage() async {
    var file = File(_productCachePath);
    if (file.existsSync()) {
      _productCache = ProductCache.fromJson(jsonDecode(utf8.decode(gzip.decode(await file.readAsBytes()))));
    }
    return _productCache;
  }

  Future<Map<int, SkuPriceCache>> _readPriceCacheFromStorage() async {
    var file = File(_priceCachePath);
    if (file.existsSync()) {
      var skuPriceCacheList = (jsonDecode(utf8.decode(gzip.decode(await file.readAsBytes()))) as List).map((e) => SkuPriceCache.fromJson(e)).toList();
      _skuPriceCacheById = Map.fromIterables(skuPriceCacheList.map((e) => e.skuPrice.skuId), skuPriceCacheList);
    }
    return _skuPriceCacheById;
  }

  Future<ProductCache> _refreshProductCache() async {
    DateTime start = DateTime.now();
    var completer = Completer<ProductCache>();
    _futureProductCache = completer.future;
    List<Category> categoryList = await _getApiCategories(inclusionRules);
    List<Group> groupList = await _getApiGroups(inclusionRules, categoryList);
    Map<int, List<Condition>> conditionsByCategoryId = await _getApiCategoryConditions(categoryList);
    Map<int, List<Printing>> printingsByCategoryId = await _getApiCategoryPrintings(categoryList);
    Map<int, List<Rarity>> raritiesByCategoryId = await _getApiCategoryRarities(categoryList);

    // Only query products for new (to me) groups or recent groups
    DateTime cutoff = DateTime.now().subtract(Duration(days: 365));
    List<Group> recentOrNewGroupList = groupList //
        .where((group) => group.publishedOn.isAfter(cutoff) || !_productCache.groupById.keys.contains(group.groupId))
        .toList();

    List<ProductExtended> recentProductList = await _getApiProductExtended(categoryList, recentOrNewGroupList);

    _productCache = ProductCache.merge(
      _productCache,
      timestamp: DateTime.now().toUtc(),
      categoryList: categoryList,
      groupList: groupList,
      conditionsByCategoryId: conditionsByCategoryId,
      printingsByCategoryId: printingsByCategoryId,
      raritiesByCategoryId: raritiesByCategoryId,
      recentProductList: recentProductList,
    );
    completer.complete(_productCache);

    DateTime end = DateTime.now();
    _logger.info(
        "_refreshProductCache Time: ${end.difference(start).inSeconds}s | Recent Group Count: ${recentOrNewGroupList.length} | Recent Product Count: ${recentProductList.length}");

    return _productCache;
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

  static Future<List<Category>> _getApiCategories(List<InclusionRule> inclusionRules) async {
    var pages = await ListAllCategories().getAllPages();
    var results = pages //
        .expand((response) => response.results)
        .where((category) => inclusionRules.any((rule) => rule.matchCategory(category)))
        .toList();
    return results;
  }

  static Future<Map<int, List<Condition>>> _getApiCategoryConditions(List<Category> categoryList) async {
    Map<int, List<Condition>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryConditions(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  static Future<Map<int, List<Printing>>> _getApiCategoryPrintings(List<Category> categoryList) async {
    Map<int, List<Printing>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryPrintings(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  static Future<Map<int, List<Rarity>>> _getApiCategoryRarities(List<Category> categoryList) async {
    Map<int, List<Rarity>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryRarities(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  static Future<List<Group>> _getApiGroups(List<InclusionRule> inclusionRules, List<Category> categoryList) async {
    List<Group> allResults = [];
    for (Category category in categoryList) {
      var pages = await ListAllCategoryGroups(categoryId: category.categoryId).getAllPages();
      var results = pages //
          .expand((response) => response.results)
          .where((group) => inclusionRules.any((rule) => rule.matchCategoryAndGroup(category, group)))
          .toList();
      allResults.addAll(results);
    }
    return allResults;
  }

  static Future<List<ProductExtended>> _getApiProductExtended(List<Category> categoryList, List<Group> groupList) async {
    List<ProductExtended> allResults = [];
    for (Category category in categoryList) {
      for (Group group in groupList.where((group) => group.categoryId == category.categoryId)) {
        var pages = await ListAllProductsExtended(categoryId: category.categoryId, groupId: group.groupId).getAllPages();
        var results = pages.expand((response) => response.results);
        allResults.addAll(results);
      }
    }
    return allResults;
  }
}
