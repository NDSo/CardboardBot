import 'package:cardboard_bot/tcgplayer_client.dart';

import '../tcgplayer_caching_client.dart';

class SkuWrapper implements Sku {
  final Sku _sku;

  SkuWrapper(Sku sku, this.product, TcgPlayerCachingClient tcgPlayerService) : _sku = sku {
    condition = tcgPlayerService
        .searchConditions(
      categoryId: product.categoryId,
      conditionId: sku.conditionId,
    )
        .first;
    printing = tcgPlayerService
        .searchPrintings(
      categoryId: product.categoryId,
      printingId: sku.printingId,
    )
        .first;
  }

  late final Product product;
  late final Condition condition;
  late final Printing printing;

  // late final Language language;

  @override
  int? get conditionId => _sku.conditionId;

  @override
  int get languageId => _sku.languageId;

  @override
  int get printingId => _sku.printingId;

  @override
  int get productId => _sku.productId;

  @override
  int get skuId => _sku.skuId;

  @override
  Map<String, dynamic> toJson() => throw UnimplementedError("$runtimeType.toJson() is not implemented!");
}
