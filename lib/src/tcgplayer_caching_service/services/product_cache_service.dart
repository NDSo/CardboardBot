import 'dart:async';

import 'package:cardboard_bot/repository.dart';
import 'package:cardboard_bot/src/monads/expiring.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/models/category_info_cache.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import '../models/inclusion_rule.dart';
import '../models/product_info_cache.dart';

//TODO: THIS IS A SHIT SHOW
abstract class ProductCacheService {

  Future<CategoryInfoCache> getCategoryInfoCache();
  Future<ProductInfoCache> getProductInfoCache({required int groupId});

  Future<List<Category>> _getApiCategories(List<InclusionRule> inclusionRules) async {
    var pages = await ListAllCategories().getAllPages();
    var results = pages //
        .expand((response) => response.results)
        .where((category) => inclusionRules.any((rule) => rule.matchCategory(category)))
        .toList();
    return results;
  }

  Future<Map<int, List<Condition>>> _getApiCategoryConditions(List<Category> categoryList) async {
    Map<int, List<Condition>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryConditions(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  Future<Map<int, List<Printing>>> _getApiCategoryPrintings(List<Category> categoryList) async {
    Map<int, List<Printing>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryPrintings(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  Future<Map<int, List<Rarity>>> _getApiCategoryRarities(List<Category> categoryList) async {
    Map<int, List<Rarity>> allResults = {};
    for (Category category in categoryList) {
      var response = await ListAllCategoryRarities(categoryId: category.categoryId).get();
      allResults.addAll({category.categoryId: response.results});
    }
    return allResults;
  }

  Future<List<Group>> _getApiGroups(List<InclusionRule> inclusionRules, List<Category> categoryList) async {
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

  Future<List<ProductExtended>> _getApiProductExtended(int groupId) async {
    List<ProductExtended> allResults = [];
    var pages = await ListAllProductsExtended(groupId: groupId).getAllPages();
    var results = pages.expand((response) => response.results);
    allResults.addAll(results);
    return allResults;
  }
}

class ProductCacheServiceHighMemory extends ProductCacheService {

  // ignore: unused_field
  static final Logger _logger = Logger("$ProductCacheServiceHighMemory");

  // CategoryInfoCache
  final List<InclusionRule> _inclusionRules;
  final Repository<CategoryInfoCache> _tier1CategoryInfoCacheRepository = LocalMemoryRepository();
  final Repository<CategoryInfoCache> _tier2CategoryInfoCacheRepository;

  // ProductInfoCache
  final Repository<ProductInfoCache> _tier1ProductInfoCacheRepository = LocalMemoryRepository();
  final Repository<ProductInfoCache> _tier2ProductInfoCacheRepository;

  ProductCacheServiceHighMemory({
    required List<InclusionRule> inclusionRules,
    required Repository<CategoryInfoCache> tier2CategoryInfoCacheRepository,
    required Repository<ProductInfoCache> tier2ProductInfoCacheRepository,
  })  :
        _inclusionRules = inclusionRules,
        _tier2CategoryInfoCacheRepository = tier2CategoryInfoCacheRepository,
        _tier2ProductInfoCacheRepository = tier2ProductInfoCacheRepository {
    _onBoot();
    // Refresh Cache Timer
    Timer.periodic(const Duration(hours: 24), (timer) async {
      _refreshCategoryInfoAndProductInfoCache(previousCache: (await _tier1CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId()))!);
    });
  }

  Future<void> _onBoot() async {
    var categoryInfoCache = await _tier2CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId());
    if (categoryInfoCache != null) {
      await _tier1CategoryInfoCacheRepository.upsert(ids: [CategoryInfoCache.buildId()], objects: [categoryInfoCache]);

      var productInfoCache = await _tier2ProductInfoCacheRepository.getAll();
      await _tier1ProductInfoCacheRepository.upsert(ids: productInfoCache.map((e) => e.getId()).toList(), objects: productInfoCache);
      if (categoryInfoCache.timestamp.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
        await _refreshCategoryInfoAndProductInfoCache(previousCache: categoryInfoCache);
      }
    } else {
      await _refreshCategoryInfoAndProductInfoCache(previousCache: CategoryInfoCache.empty());
    }
  }

  @override
  Future<CategoryInfoCache> getCategoryInfoCache() async {
    try {
      // Hit Tier 1
      var cache = await _tier1CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId());
      return cache!;
    } catch (e, stacktrace) {
      // Release Lock
      _logger.severe("Failed to getCategoryInfoCache()!", e, stacktrace);
      rethrow;
    }
  }

  @override
  Future<ProductInfoCache> getProductInfoCache({required int groupId}) async {
    try {
      // Hit Tier 1
      var productInfoCache = (await _tier1ProductInfoCacheRepository.getById(ProductInfoCache.buildId(groupId)));
      return productInfoCache!;
    } catch (e, stacktrace) {
      _logger.severe("Failed to getProductInfoCache(groupId: $groupId)!", e, stacktrace);
      rethrow;
    }
  }

  Future<CategoryInfoCache> _refreshCategoryInfoAndProductInfoCache({required CategoryInfoCache previousCache}) async {
    Stopwatch stopwatch = Stopwatch()..start();
    var timestamp = DateTime.now().toUtc();

    List<Category> categoryList = await _getApiCategories(_inclusionRules);
    Set<Group> groups = (await _getApiGroups(_inclusionRules, categoryList)).toSet();
    Map<int, List<Condition>> conditionsByCategoryId = await _getApiCategoryConditions(categoryList);
    Map<int, List<Printing>> printingsByCategoryId = await _getApiCategoryPrintings(categoryList);
    Map<int, List<Rarity>> raritiesByCategoryId = await _getApiCategoryRarities(categoryList);

    // Only query products for new (to me) groups or recent groups
    Set<Group> recentExistingGroups = groups //
        .where((group) => group.modifiedOn.isAfter(previousCache.timestamp) && previousCache.groupById.keys.contains(group.groupId))
        .toSet();

    Set<Group> newGroups = groups //
        .where((group) => !previousCache.groupById.keys.contains(group.groupId))
        .toSet();

    // Update Product Cache and write to database
    Set<Group> successfullyCachedNewGroups = {};
    List<ProductInfoCache> productInfoCacheList = [];
    Map<int, int> groupIdByProductId = {};

    for (var group in [...recentExistingGroups, ...newGroups]) {
      List<ProductExtended> groupProductList = await _getApiProductExtended(group.groupId);
      try {
        productInfoCacheList.add(ProductInfoCache(timestamp: DateTime.now(), groupId: group.groupId, productList: groupProductList));
        groupIdByProductId.addAll({
          for (var product in groupProductList) product.productId: group.groupId,
        });
        if (newGroups.contains(group)) successfullyCachedNewGroups.add(group);
      } catch (e, stacktrace) {
        _logger.severe("Failed to save category: ${group.categoryId} group: ${group.groupId} to cloud!", e, stacktrace);
      }
    }

    groups.removeAll(newGroups.difference(successfullyCachedNewGroups));

    // Merge category group cache
    var freshCategoryGroupCache = CategoryInfoCache(
      timestamp: timestamp,
      categoryList: categoryList,
      groupList: groups.toList(),
      conditionsByCategoryId: conditionsByCategoryId,
      printingsByCategoryId: printingsByCategoryId,
      raritiesByCategoryId: raritiesByCategoryId,
      groupIdByProductId: {
        ...previousCache.groupIdByProductId,
        ...groupIdByProductId,
      },
    );

    await _tier1CategoryInfoCacheRepository.upsert(
      objects: [freshCategoryGroupCache],
      ids: [freshCategoryGroupCache.getId()],
    );

    await _tier2CategoryInfoCacheRepository.upsert(
      objects: [freshCategoryGroupCache],
      ids: [freshCategoryGroupCache.getId()],
    );

    await _tier1ProductInfoCacheRepository.upsert(
      objects: productInfoCacheList,
      ids: productInfoCacheList.map((e) => e.getId()).toList(),
    );

    await _tier2ProductInfoCacheRepository.upsert(
      objects: productInfoCacheList,
      ids: productInfoCacheList.map((e) => e.getId()).toList(),
    );

    // Log and Return
    stopwatch.stop();
    _logger.info(
        "_refreshProductCache Time: ${stopwatch.elapsed.inSeconds}s | Recent Groups: ${recentExistingGroups.length} | New Groups: ${newGroups.length} | Recent&New Products: ${groupIdByProductId.length}");

    return freshCategoryGroupCache;
  }
}

class ProductCacheServiceLowMemory extends ProductCacheService {
  // ignore: unused_field
  static final Logger _logger = Logger("$ProductCacheServiceLowMemory");

  // CategoryInfoCache
  final List<InclusionRule> _inclusionRules;
  final Repository<CategoryInfoCache> _tier1CategoryInfoCacheRepository = LocalMemoryRepository();
  final Repository<CategoryInfoCache> _tier2CategoryInfoCacheRepository;

  // ProductInfoCache
  final Duration _productInfoCacheLifespan;
  final Map<int, Future<void>> _productInfoCacheLocks = {};
  final Repository<Expiring<ProductInfoCache>> _tier1ProductInfoCacheRepository = LocalMemoryRepository();
  final Repository<ProductInfoCache> _tier2ProductInfoCacheRepository;

  ProductCacheServiceLowMemory({
    required Duration productInfoCacheLifespan,
    required List<InclusionRule> inclusionRules,
    required Repository<CategoryInfoCache> tier2CategoryInfoCacheRepository,
    required Repository<ProductInfoCache> tier2ProductInfoCacheRepository,
  })  : _productInfoCacheLifespan = productInfoCacheLifespan,
        _inclusionRules = inclusionRules,
        _tier2CategoryInfoCacheRepository = tier2CategoryInfoCacheRepository,
        _tier2ProductInfoCacheRepository = tier2ProductInfoCacheRepository {
    // Pre fill cache
    _onBoot();
    // Refresh CategoryInfoCache Timer
    Timer.periodic(const Duration(hours: 24), (timer) async {
      _refreshCategoryInfoAndProductInfoCache(previousCache: (await _tier1CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId()))!);
    });
    // Refresh ProductInfoCache Timer
    Timer.periodic(productInfoCacheLifespan ~/ 10, (timer) async {
      var cache = await _tier1ProductInfoCacheRepository.getAll();
      var expiredIds = cache.where((element) => element.isExpired()).map((e) => e.object.getId()).toSet();
      await _tier1ProductInfoCacheRepository.delete(expiredIds);
    });
  }

  Future<void> _onBoot() async {
    // await MemCheck.printMemoryUsage();
    var categoryInfoCache = await _tier2CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId());
    if (categoryInfoCache != null) {
      await _tier1CategoryInfoCacheRepository.upsert(ids: [CategoryInfoCache.buildId()], objects: [categoryInfoCache]);
      if (categoryInfoCache.timestamp.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        await _refreshCategoryInfoAndProductInfoCache(previousCache: categoryInfoCache);
      }
    } else {
      await _refreshCategoryInfoAndProductInfoCache(previousCache: CategoryInfoCache.empty());
    }
  }

  @override
  Future<CategoryInfoCache> getCategoryInfoCache() async {
    try {
      // Hit Tier 1
      var cache = await _tier1CategoryInfoCacheRepository.getById(CategoryInfoCache.buildId());
      return cache!;
    } catch (e, stacktrace) {
      _logger.severe("Failed to getCategoryInfoCache()!", e, stacktrace);
      rethrow;
    }
  }

  @override
  Future<ProductInfoCache> getProductInfoCache({required int groupId}) async {
    // Await Lock
    await _productInfoCacheLocks[groupId];

    // Lock Cache
    var completer = Completer<void>();
    _productInfoCacheLocks[groupId] = completer.future;

    ProductInfoCache? productInfoCache;

    try {
      // Hit Tier 1
      productInfoCache = (await _tier1ProductInfoCacheRepository.getById(ProductInfoCache.buildId(groupId)))?.resetExpiryIfFresh().freshObjectOrNull;

      // Hit Tier 2 if necessary
      if (productInfoCache == null) {
        productInfoCache ??= await _tier2ProductInfoCacheRepository.getById(ProductInfoCache.buildId(groupId));
        if (productInfoCache != null) {
          await _tier1ProductInfoCacheRepository.upsert(
            objects: [Expiring(productInfoCache, lifespan: _productInfoCacheLifespan)],
            ids: [productInfoCache.getId()],
          );
        }
      }

      // Release Lock
      completer.complete();
      return productInfoCache!;
    } catch (e, stacktrace) {
      // Release Lock
      if (!completer.isCompleted) completer.complete();
      _logger.severe("Failed to getProductInfoCache(groupId: $groupId)!", e, stacktrace);
      rethrow;
    }
  }

  Future<CategoryInfoCache> _refreshCategoryInfoAndProductInfoCache({required CategoryInfoCache previousCache}) async {
    Stopwatch stopwatch = Stopwatch()..start();
    var timestamp = DateTime.now().toUtc();

    List<Category> categoryList = await _getApiCategories(_inclusionRules);
    Set<Group> groups = (await _getApiGroups(_inclusionRules, categoryList)).toSet();
    Map<int, List<Condition>> conditionsByCategoryId = await _getApiCategoryConditions(categoryList);
    Map<int, List<Printing>> printingsByCategoryId = await _getApiCategoryPrintings(categoryList);
    Map<int, List<Rarity>> raritiesByCategoryId = await _getApiCategoryRarities(categoryList);

    // Only query products for new (to me) groups or recent groups
    // modifiedOn data looks reasonable, publishedOn data is very wrong (now) for 25% of the groups
    Set<Group> recentExistingGroups = groups //
        .where((group) => group.modifiedOn.isAfter(previousCache.timestamp) && previousCache.groupById.keys.contains(group.groupId))
        .toSet();

    Set<Group> newGroups = groups //
        .where((group) => !previousCache.groupById.keys.contains(group.groupId))
        .toSet();

    // Update Product Cache and write to database
    Set<Group> successfullyCachedNewGroups = {};
    Map<int, int> groupIdByProductId = {};

    for (var group in [...recentExistingGroups, ...newGroups]) {
      List<ProductExtended> groupProductList = await _getApiProductExtended(group.groupId);
      try {
        ProductInfoCache productInfoCache = ProductInfoCache(timestamp: DateTime.now(), groupId: group.groupId, productList: groupProductList);
        await _tier2ProductInfoCacheRepository.upsert(
          objects: [productInfoCache],
          ids: [productInfoCache.getId()],
        );
        groupIdByProductId.addAll({
          for (var product in groupProductList) product.productId: group.groupId,
        });
        if (newGroups.contains(group)) successfullyCachedNewGroups.add(group);
      } catch (e, stacktrace) {
        _logger.severe("Failed to save category: ${group.categoryId} group: ${group.groupId} to cloud!", e, stacktrace);
      }
    }

    groups.removeAll(newGroups.difference(successfullyCachedNewGroups));

    // Merge category group cache
    var freshCategoryGroupCache = CategoryInfoCache(
      timestamp: timestamp,
      categoryList: categoryList,
      groupList: groups.toList(),
      conditionsByCategoryId: conditionsByCategoryId,
      printingsByCategoryId: printingsByCategoryId,
      raritiesByCategoryId: raritiesByCategoryId,
      groupIdByProductId: {
        ...previousCache.groupIdByProductId,
        ...groupIdByProductId,
      },
    );

    await _tier1CategoryInfoCacheRepository.upsert(
      objects: [freshCategoryGroupCache],
      ids: [freshCategoryGroupCache.getId()],
    );

    await _tier2CategoryInfoCacheRepository.upsert(
      objects: [freshCategoryGroupCache],
      ids: [freshCategoryGroupCache.getId()],
    );

    // Log and Return
    stopwatch.stop();
    _logger.info(
        "_refreshProductCache Time: ${stopwatch.elapsed.inSeconds}s | Recent Groups: ${recentExistingGroups.length} | New Groups: ${newGroups.length} | Recent&New Products: ${groupIdByProductId.length}");

    return freshCategoryGroupCache;
  }
}
