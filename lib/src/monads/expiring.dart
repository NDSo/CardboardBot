import 'dart:async';

class Expiring<A> {
  A object;
  Duration lifespan;
  bool _isExpired = false;

  late Timer _timer;
  final Completer<Expiring<A>> _completer = Completer();

  Expiring(this.object, {required this.lifespan}) {
    _timer = Timer(lifespan, () {
      _isExpired = true;
      _completer.complete(this);
    });
  }

  Expiring<A> resetExpiryIfFresh() {
    if (isFresh()) {
      _timer.cancel();
      _timer = Timer(lifespan, () {
        _isExpired = true;
        _completer.complete(this);
      });
    }
    return this;
  }

  Future<Expiring<A>> get onExpired => _completer.future;

  bool isExpired() => _isExpired;

  bool isFresh() => !_isExpired;

  A? get freshObjectOrNull => isFresh() ? object : null;
}
