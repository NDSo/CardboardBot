import 'dart:async';
import 'dart:convert';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/src/google_cloud_services/google_cloud_service.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import '../models/category_group_cache.dart';
import '../models/inclusion_rule.dart';

class CategoryGroupCachingService {
  // ignore: unused_field
  static final Logger _logger = Logger("$CategoryGroupCachingService");
  static CategoryGroupCachingService? _singleton;

  static Future<CategoryGroupCachingService> initialize(List<InclusionRule> inclusionRules) async {
    if (_singleton != null) {
      _logger.warning("Tried to initialize $CategoryGroupCachingService more than once!");
      return _singleton!;
    }
    _singleton ??= CategoryGroupCachingService._internal(inclusionRules: inclusionRules);
    await _singleton!._initialize();
    return _singleton!;
  }

  factory CategoryGroupCachingService() {
    if (_singleton == null) throw Exception("$CategoryGroupCachingService needs initialized!");
    return _singleton!;
  }

  CategoryGroupCachingService._internal({required this.inclusionRules});

  //Caching Logic
  List<InclusionRule> inclusionRules;

  final JsonEncoder _jsonEncoder = JsonEncoder();
  static const String _productCachePath = 'cardboard_bot/data/tcgplayer/product_cache.gzip';

  Timer? _refreshProductCacheTimer;

  // Local Category and Group cache
  CategoryGroupCache _categoryGroupCache = CategoryGroupCache.empty();

  CategoryGroupCache get categoryGroupCache => _categoryGroupCache;

  DateTime get productCacheTimestamp => _categoryGroupCache.timestamp;

  // Remote Product List Cache
  String _productCacheFirestorePath(int groupId) => "productsByGroup/groupId=$groupId";

  Future<void> _initialize() async {
    await _readCategoryGroupCacheFromStorage();

    // Run Now
    if (DateTime.now().toUtc().isAfter(_categoryGroupCache.timestamp.add(Duration(hours: 24)))) {
      await _refreshCategoryGroupCache();
    }

    // Run Timers
    _refreshProductCacheTimer?.cancel();
    _refreshProductCacheTimer = Timer.periodic(Duration(hours: 24), (timer) => _refreshCategoryGroupCache());
  }

  Future<void> _writeCategoryGroupCacheToStorage() async {
    // var file = File(_productCachePath);
    // file.createSync(recursive: true);
    // file.writeAsBytesSync(gzip.encode(utf8.encode(_jsonEncoder.convert(_productCache))));
    GoogleCloudService().write(object: _categoryGroupCache, name: "TcgPlayerProductCache", zip: true);
  }

  Future<CategoryGroupCache> _readCategoryGroupCacheFromStorage() async {
    // var file = File(_productCachePath);
    // if (file.existsSync()) {
    //   _productCache = ProductCache.fromJson(jsonDecode(utf8.decode(gzip.decode(await file.readAsBytes()))));
    // }
    // return _productCache;
    _categoryGroupCache =
        await GoogleCloudService().read<CategoryGroupCache>(fromJson: (json) => CategoryGroupCache.fromJson(json as Map<String, dynamic>), name: "TcgPlayerProductCache", zip: true) ??
            _categoryGroupCache;
    return _categoryGroupCache;
  }

  Future<void> _refreshCategoryGroupCache() async {
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    List<Category> categoryList = await _getApiCategories(inclusionRules);
    Set<Group> groups = (await _getApiGroups(inclusionRules, categoryList)).toSet();
    Map<int, List<Condition>> conditionsByCategoryId = await _getApiCategoryConditions(categoryList);
    Map<int, List<Printing>> printingsByCategoryId = await _getApiCategoryPrintings(categoryList);
    Map<int, List<Rarity>> raritiesByCategoryId = await _getApiCategoryRarities(categoryList);

    // Only query products for new (to me) groups or recent groups
    DateTime cutoff = DateTime.now().subtract(Duration(days: 30));
    Set<Group> recentExistingGroups = groups //
        .where((group) => group.publishedOn.isAfter(cutoff) && _categoryGroupCache.groupById.keys.contains(group.groupId))
        .toSet();

    Set<Group> newGroups = groups //
        .where((group) => !_categoryGroupCache.groupById.keys.contains(group.groupId))
        .toSet();

    // Update Product Cache and write to database
    Map<int, Map<int, Set<int>>> skuIdByProductIdByGroupId = {};
    Set<Group> successfullyCachedNewGroups = {};
    var updateProductCacheFutures = [...recentExistingGroups, ...newGroups].map((group) async {
      List<ProductExtended> groupProductList = await _getApiProductExtended(group);
      try {
        //TODO: How the hell is something over 1 MB btw
        await GoogleCloudService().patch(object: groupProductList, name: _productCacheFirestorePath(group.groupId), zip: true);
        skuIdByProductIdByGroupId[group.groupId] = groupProductList.fold<Map<int, Set<int>>>(
          <int, Set<int>>{},
              (t, e) => t..addAll({e.productId: e.skus.map((e) => e.skuId).toSet()}),
        );
        if (newGroups.contains(group)) successfullyCachedNewGroups.add(group);
      } catch (e, stacktrace) {
        _logger.severe("Failed to save category: ${group.categoryId} group: ${group.groupId} to cloud!", e, stacktrace);
      }
      return;
    }).toList();

    await Future.wait(updateProductCacheFutures);

    groups.removeAll(newGroups.difference(successfullyCachedNewGroups));

    // Merge category group cache
    _categoryGroupCache = CategoryGroupCache(
      timestamp: DateTime.now().toUtc(),
      categoryList: categoryList,
      groupList: groups.toList(),
      conditionsByCategoryId: conditionsByCategoryId,
      printingsByCategoryId: printingsByCategoryId,
      raritiesByCategoryId: raritiesByCategoryId,
      // Merge Previous Product Ids
      skuIdByProductIdByGroupId: {
        ..._categoryGroupCache.skuIdByProductIdByGroupId,
        ...skuIdByProductIdByGroupId,
      },
    );

    await _writeCategoryGroupCacheToStorage();

    // Log and Return
    stopwatch.stop();
    _logger.info(
        "_refreshProductCache Time: ${stopwatch.elapsed.inSeconds}s | Recent Groups: ${recentExistingGroups.length} | New Groups: ${newGroups.length} | Recent Products: ${skuIdByProductIdByGroupId.values.expand((element) => element.keys).length}");
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

  static Future<List<ProductExtended>> _getApiProductExtended(Group group) async {
    List<ProductExtended> allResults = [];
    var pages = await ListAllProductsExtended(groupId: group.groupId).getAllPages();
    var results = pages.expand((response) => response.results);
    allResults.addAll(results);
    return allResults;
  }
}
