import 'dart:async';

import 'package:cardboard_bot/extensions.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/models/sku_model.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';

import 'models/product_model.dart';
import 'models/sku_price_cache.dart';
import 'services/price_cache_service.dart';
import 'services/product_cache_service.dart';

class TcgPlayerCachingClient {
  // ignore: unused_field
  static final Logger _logger = Logger("$TcgPlayerCachingClient");

  final ProductCacheService _productCacheService;
  final PriceCacheService _priceCacheService;

  TcgPlayerCachingClient(this._productCacheService, this._priceCacheService);

  bool _match<T>(T? a, bool Function(T a) match) => a == null ? true : match(a);

  bool _matchInt(int? a, int? field) => _match<int>(a, (a) => a == field);

  bool _matchRegex(RegExp? a, String? field) => _match<RegExp>(a, (a) => a.hasMatch(field ?? ""));

  Future<List<Category>> searchCategories({int? categoryId, RegExp? anyName, RegExp? name, RegExp? displayName}) async {
    return (await _productCacheService.getCategoryInfoCache())
        .categoryList
        .where(
          (e) =>
              _matchInt(categoryId, e.categoryId) &&
              _match<RegExp>(anyName, (a) => e.matchAnyName(a)) &&
              _matchRegex(name, e.name) &&
              _matchRegex(displayName, e.displayName),
        )
        .toList();
  }

  Future<List<Group>> searchGroups({int? groupId, int? categoryId, RegExp? name}) async {
    return (await _productCacheService.getCategoryInfoCache())
        .groupList
        .where(
          (e) => _matchInt(groupId, e.groupId) && _matchInt(categoryId, e.categoryId) && _matchRegex(name, e.name),
        )
        .toList();
  }

  Future<List<ProductModel>> searchProductsBySkuId({required int skuId}) async {
    var cache = (await _productCacheService.getCategoryInfoCache());
    int groupId = cache.groupIdByProductId[cache.productIdBySkuId[skuId]]!;
    return _searchProducts(groupId: groupId, skuId: skuId);
  }

  Future<List<ProductModel>> searchProductsByProductId({required int productId}) async {
    int groupId = (await _productCacheService.getCategoryInfoCache()).groupIdByProductId[productId]!;
    return _searchProducts(groupId: groupId, productId: productId);
  }

  Future<List<ProductModel>> searchProductsByGroupId({required int groupId, RegExp? anyName}) async {
    return _searchProducts(groupId: groupId, anyName: anyName);
  }

  Future<List<ProductModel>> _searchProducts({int? productId, required int groupId, RegExp? anyName, int? skuId}) async {
    var categoryCache = await _productCacheService.getCategoryInfoCache();
    Group group = categoryCache.groupById.get(groupId)!;
    Category category = categoryCache.categoryById.get(group.categoryId)!;
    Map<int, Printing> printings = {
      for (var printing in categoryCache.printingsByCategoryId.get(category.categoryId)!) printing.printingId: printing,
    };
    Map<int, Condition> conditions = {
      for (var condition in categoryCache.conditionsByCategoryId.get(category.categoryId)!) condition.conditionId: condition,
    };

    List<ProductExtended> products = (await _productCacheService.getProductInfoCache(groupId: groupId)).productList;

    return products
        .where(
          (product) =>
              // _matchInt(groupId, e.groupId) &&
              _match<RegExp>(anyName, (a) => product.matchAnyName(a)) &&
              _matchInt(productId, product.productId) &&
              _match<int>(skuId, (skuId) => product.skus.any((sku) => sku.skuId == skuId)),
        )
        .map(
          (product) => ProductModel(
            product,
            category: category,
            group: group,
            skus: product.skus
                .map(
                  (sku) => SkuModel(
                    sku,
                    condition: conditions[sku.conditionId],
                    printing: printings[sku.printingId]!,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  Future<Map<int, SkuPriceCache>> searchSkuPriceCachesBySkuIds({required List<int> skuIds}) async {
    return (await _priceCacheService.getSkuPriceCache(skuIds: skuIds));
  }

  Future<List<Condition>> searchConditions({required int categoryId, int? conditionId}) async {
    return ((await _productCacheService.getCategoryInfoCache()).conditionsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(conditionId, e.conditionId),
        )
        .toList();
  }

  Future<List<Printing>> searchPrintings({required int categoryId, int? printingId}) async {
    return ((await _productCacheService.getCategoryInfoCache()).printingsByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(printingId, e.printingId),
        )
        .toList();
  }

  Future<List<Rarity>> searchRarities({required int categoryId, int? rarityId}) async {
    return ((await _productCacheService.getCategoryInfoCache()).raritiesByCategoryId[categoryId] ?? []) //
        .where(
          (e) => _matchInt(rarityId, e.rarityId),
        )
        .toList();
  }
}
