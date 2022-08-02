import '../../tcgplayer_client/models/product.dart';

class ProductLocalCache {
  DateTime _expires;
  List<ProductExtended> products;

  static const Duration _lifespan = Duration(seconds: 10);
  ProductLocalCache(this.products) : _expires = DateTime.now().add(_lifespan);

  void resetExpiry() => _expires = DateTime.now().add(_lifespan);
  bool isExpired() => _expires.isAfter(DateTime.now());
  bool isFresh() => !isExpired();
}