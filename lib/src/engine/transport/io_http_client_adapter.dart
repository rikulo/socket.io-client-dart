import 'dart:io';
import 'http_client_adapter.dart';

class IOHttpClientAdapter implements HttpClientAdapter {
  final HttpClient _httpClient;

  IOHttpClientAdapter([HttpClient? httpClient])
      : _httpClient = httpClient ?? HttpClient();

  @override
  Future<WebSocket> connect(String uri, {Map<String, dynamic>? headers}) {
    return WebSocket.connect(
      uri,
      headers: headers,
      customClient: _httpClient,
    );
  }
}

HttpClientAdapter makePlatformHttpClientAdapter() {
  return IOHttpClientAdapter();
}
