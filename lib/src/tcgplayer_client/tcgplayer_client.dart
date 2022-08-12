import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';

void initializeTcgPlayerClient({required String publicKey, required String privateKey}) {
  if (!TcgPlayerClient.isInitialized()) TcgPlayerClient.initialize(publicKey, privateKey);
}

class TcgPlayerClient extends IOClient {
  final Logger logger = Logger("TcgPlayerClient");
  static final DateFormat dateFormat = DateFormat("EEE, d MMM yyyy HH:mm:ss zzz");

  final String _publicKey;
  final String _privateKey;
  static TcgPlayerClient? _singleton;
  static final Uri _baseUri = Uri(
    scheme: "https",
    host: "api.tcgplayer.com",
  );

  static bool isInitialized() => _singleton != null;

  factory TcgPlayerClient.initialize(String publicKey, String privateKey) {
    _singleton ??= TcgPlayerClient._internal(publicKey, privateKey);
    return _singleton!;
  }

  factory TcgPlayerClient() {
    if (_singleton == null) throw Exception("$TcgPlayerClient needs initialized with credentials!");
    return _singleton!;
  }

  TcgPlayerClient._internal(this._publicKey, this._privateKey) {
    _setupTimer();
  }

  _BearerToken? _bearerToken;

  Future<void> _refreshBearerToken() async {
    if (_bearerToken?.isExpiring() ?? true) {
      var response = await super.post(
        _baseUri.replace(
          pathSegments: ["token"],
        ),
        body: {
          "grant_type": "client_credentials",
          "client_id": _publicKey,
          "client_secret": _privateKey,
        },
      );
      _bearerToken = _BearerToken.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
  }

  Future<Map<String, String>> _getRequestHeaders() async {
    await _refreshBearerToken();
    return {
      "Accept": "application/json",
      "Authorization": "bearer ${_bearerToken!.value}",
      "User-Agent": "CardboardBot/0.1.0",
    };
  }

  void _setupTimer() async {
    //TODO: Get rid of this timer, let _addToQueue kick off a queue loop or something
    // TODO: And experiment with x requests per minute rather than 1 request per x ms.
    if (_scheduledQueue.isNotEmpty) {
      var scheduledF = _scheduledQueue.removeFirst();
      try {
        await scheduledF();
      } finally {
        Timer(minTimeout, _setupTimer);
      }
    } else {
      Timer(const Duration(milliseconds: 5), _setupTimer);
    }
  }

  // Limit is 300 per minute, one every 200ms.
  static const Duration minTimeout = Duration(milliseconds: 400);

  final Queue<Function> _scheduledQueue = Queue<Function>();

  Future<T> _addToQueue<T>(Future<T> Function() apiRequestF) async {
    Completer<T> completer = Completer();

    Future<void> scheduledF() async {
      completer.complete(apiRequestF());
      return;
    }

    _scheduledQueue.add(scheduledF);

    return completer.future;
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) async => _addToQueue<Response>(() async => super.get(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
      ));

  @override
  Future<Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _addToQueue<Response>(() async => super.post(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _addToQueue<Response>(() async => super.put(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _addToQueue<Response>(() async => super.patch(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _addToQueue<Response>(() async => super.delete(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async => _addToQueue<String>(() async => super.read(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
      ));
}

class _BearerToken {
  final String _value;

  // ignore: unused_field
  final DateTime _issued;
  final DateTime _expires;

  String get value => _value;

  bool isExpiring() => DateTime.now() //
      .add(Duration(hours: 1))
      .isAfter(_expires);

  _BearerToken(this._value, this._issued, this._expires);

  factory _BearerToken.fromJson(Map<String, dynamic> json) => _BearerToken(
        json["access_token"] as String,
        TcgPlayerClient.dateFormat.parse(json[".issued"] as String),
        TcgPlayerClient.dateFormat.parse(json[".expires"] as String),
      );
}
