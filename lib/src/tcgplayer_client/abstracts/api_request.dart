import 'dart:convert';

import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';

import '../tcgplayer_client.dart';
import 'api_response.dart';

abstract class ApiRequest<T extends ApiBaseResponse> {
  @JsonKey(ignore: true)
  TcgPlayerClient client = TcgPlayerClient();

  Uri getUri() => Uri(
        pathSegments: [
          getVersion(),
          ...getPathSegments(),
        ],
        queryParameters: getQueryParameters(),
      );

  Map<String, dynamic>? toJson();

  Map<String, String>? getQueryParameters() => toJson()?.map((key, value) => MapEntry<String, String>(key, value.toString()));

  List<String> getPathSegments();

  String getVersion() => "v1.39.0";

  T parseJsonResponse(Map<String, dynamic> json);
}

mixin BaseRequest<T extends ApiBaseResponse> on ApiRequest<T> {
  Future<T> get();
}

mixin PagedRequest<T extends ApiPagedResponse> on ApiRequest<T> {
  Future<T> getPage({required int offset, required int limit});

  Future<List<T>> getAllPages() async {
    int offset = 0;
    int limit = 100;
    int total = 0;
    List<T> pages = [];
    do {
      var response = await getPage(offset: offset, limit: limit);
      pages.add(response);
      total = response.totalItems;
      offset += response.results.length;
    } while (offset < total);
    return pages;
  }
}

abstract class ApiGetRequest<T extends ApiBaseResponse> extends ApiRequest<T> with BaseRequest<T> {
  @override
  Future<T> get() async {
    Response response = await client.get(
      getUri(),
    );
    return parseJsonResponse(jsonDecode(response.body));
  }
}

abstract class ApiPostRequest<T extends ApiBaseResponse> extends ApiRequest<T> with BaseRequest<T> {
  Map<String, dynamic> getBody();

  @override
  Future<T> get() async {
    Response response = await client.post(
      getUri(),
      body: getBody(),
    );
    return parseJsonResponse(jsonDecode(response.body));
  }
}

abstract class ApiGetPagedRequest<T extends ApiPagedResponse> extends ApiRequest<T> with PagedRequest<T> {
  @override
  Future<T> getPage({required int offset, required int limit}) async {
    var jsonResponse = (await client.get(
      getUri().replace(
        queryParameters: {
          ...?getQueryParameters(),
          "limit": limit.toString(),
          "offset": offset.toString(),
        },
      ),
    ));
    var response = parseJsonResponse(jsonDecode(jsonResponse.body));
    return response;
  }
}

abstract class ApiPostPagedRequest<T extends ApiPagedResponse> extends ApiRequest<T> with PagedRequest<T> {
  Map<String, dynamic> getBody();

  @override
  Future<T> getPage({required int offset, required int limit}) async {
    var jsonResponse = (await client.post(
      getUri(),
      body: {
        ...getBody(),
        "limit": limit.toString(),
        "offset": offset.toString(),
      },
    ));
    var response = parseJsonResponse(jsonDecode(jsonResponse.body));
    return response;
  }
}
