import 'package:cardboard_bot/tcgplayer_client.dart';

import '../tcgplayer_caching_service.dart';
import 'sku_wrapper.dart';

class ProductWrapper implements ProductExtended {
  final ProductExtended _productExtended;

  ProductWrapper(ProductExtended product, TcgPlayerCachingService tcgPlayerService)
      : _productExtended = product,
        cachedOn = tcgPlayerService.productCacheTimestamp,
        category = tcgPlayerService
            .searchCategories(
          categoryId: product.categoryId,
        )
            .first,
        group = tcgPlayerService.searchGroups(groupId: product.groupId).first,
        skus = product.skus.map((sku) => SkuWrapper(sku, tcgPlayerService)).toList();

  final DateTime cachedOn;
  final Category category;
  final Group group;
  @override
  final List<SkuWrapper> skus;

  @override
  int get categoryId => _productExtended.categoryId;

  @override
  String? get cleanName => _productExtended.cleanName;

  @override
  List<ExtendedData> get extendedData => _productExtended.extendedData;

  @override
  int get groupId => _productExtended.groupId;

  @override
  int get imageCount => _productExtended.imageCount;

  @override
  Uri get imageUrl => _productExtended.imageUrl;

  @override
  DateTime get modifiedOn => _productExtended.modifiedOn;

  @override
  String get name => _productExtended.name;

  @override
  PresaleInfo get presaleInfo => _productExtended.presaleInfo;

  @override
  int get productId => _productExtended.productId;

  @override
  Uri get url => _productExtended.url;

  @override
  bool matchAnyName(RegExp regExp) => _productExtended.matchAnyName(regExp);

  @override
  Map<String, dynamic> toJson() => throw UnimplementedError("$runtimeType.toJson() is not implemented!");
}
