import 'dart:html';
import 'http_client_adapter.dart';

class HtmlHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<WebSocket> connect(String uri, {Map<String, dynamic>? headers}) {
    return Future.value(WebSocket(uri));
  }
}

HttpClientAdapter makePlatformHttpClientAdapter() {
  return HtmlHttpClientAdapter();
}
