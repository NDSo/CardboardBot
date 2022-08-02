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

  TcgPlayerClient._internal(this._publicKey, this._privateKey);

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

  final Queue<Completer<dynamic>> _taskQueue = Queue<Completer<dynamic>>();

  // Limit is 300 per minute, one every 200ms.
  static const Duration minTimeout = Duration(milliseconds: 400);

  Future<T> _throttled<T>(Future<T> Function() apiRequestF) async {
    Completer<T> newCompleter = Completer();
    Completer<dynamic>? previousCompleter;
    if (_taskQueue.isNotEmpty) previousCompleter = _taskQueue.last;

    Future<T> scheduledF(Completer<dynamic>? previous) async {
      if (previous != null) {
        await previous.future;
        _taskQueue.remove(previous);
      }
      // Force every request to take at least 200ms, this kind of sucks but it is simpler throttle logic
      DateTime start = DateTime.now();
      T apiResponse = await apiRequestF();
      DateTime end = DateTime.now();
      Duration timeout = minTimeout - end.difference(start);
      if (!timeout.isNegative) await Future<void>.delayed(timeout);
      return apiResponse;
    }

    _taskQueue.add(newCompleter);
    newCompleter.complete(scheduledF(previousCompleter));
    return newCompleter.future;
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) async => _throttled<Response>(() async => super.get(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
      ));

  @override
  Future<Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _throttled<Response>(() async => super.post(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _throttled<Response>(() async => super.put(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _throttled<Response>(() async => super.patch(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async => _throttled<Response>(() async => super.delete(
        url.replace(scheme: _baseUri.scheme, host: _baseUri.host),
        headers: (await _getRequestHeaders())..addAll(headers ?? {}),
        body: body,
        encoding: encoding,
      ));

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async => _throttled<String>(() async => super.read(
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
