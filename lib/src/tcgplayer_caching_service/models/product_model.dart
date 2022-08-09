import 'package:cardboard_bot/tcgplayer_client.dart';
import 'sku_model.dart';

class ProductModel implements ProductExtended {
  final ProductExtended _productExtended;
  final Category category;
  final Group group;
  @override
  final List<SkuModel> skus;

  ProductModel(
    this._productExtended, {
    required this.category,
    required this.group,
    required this.skus,
  });

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
  Map<String, dynamic> toJson() => throw UnimplementedError("$ProductModel.toJson() is not implemented!");
}
