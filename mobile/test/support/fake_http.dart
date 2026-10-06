import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class RecordedRequest {
  RecordedRequest(RequestOptions options)
      : path = options.path,
        queryParameters = Map<String, dynamic>.of(options.queryParameters),
        headers = Map<String, dynamic>.of(options.headers),
        data = options.data;

  final String path;
  final Map<String, dynamic> queryParameters;
  final Map<String, dynamic> headers;
  final dynamic data;
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final AdapterHandler handler;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(RecordedRequest(options));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
