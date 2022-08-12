import 'package:cardboard_bot/tcgplayer_client.dart';

class SkuModel implements Sku {
  final Sku _sku;
  final Condition? condition;
  final Printing printing;

  SkuModel(
    this._sku, {
    required this.condition,
    required this.printing,
  });

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
  Map<String, dynamic> toJson() => throw UnimplementedError("$SkuModel.toJson() is not implemented!");
}
