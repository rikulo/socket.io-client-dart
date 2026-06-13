@TestOn('vm')
library;

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart' as ws;
import 'package:socket_io_client/socket_io_client.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/engine/transport/legacy_adapter_connector.dart';

/// Legacy-style adapter that wraps a `dart:io` [HttpClient] and returns a
/// `dart:io` [WebSocket], exactly like the adapter API shipped in 3.1.1–3.1.4.
class _IODartAdapter implements HttpClientAdapter {
  String? lastUri;
  Map<String, dynamic>? lastHeaders;

  @override
  Future<dynamic> connect(String uri, {Map<String, dynamic>? headers}) {
    lastUri = uri;
    lastHeaders = headers;
    return WebSocket.connect(uri, headers: headers);
  }
}

void main() {
  group('HttpClientAdapter backward compatibility (#442)', () {
    test('OptionBuilder.setHttpClientAdapter stores the adapter', () {
      final adapter = _IODartAdapter();
      final options = OptionBuilder().setHttpClientAdapter(adapter).build();

      expect(options['httpClientAdapter'], same(adapter));
    });

    test('Manager translates httpClientAdapter into a webSocketConnector', () {
      final adapter = _IODartAdapter();
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'httpClientAdapter': adapter, 'autoConnect': false},
      );

      final transportOptions = manager.options!['transportOptions'] as Map;
      final websocket = transportOptions['websocket'] as Map;
      expect(websocket['webSocketConnector'], isNotNull);
    });

    test(
        'connectViaAdapter calls the adapter and adapts a dart:io WebSocket '
        'into a package:web_socket WebSocket', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      HttpHeaders? receivedHeaders;
      server.listen((request) async {
        receivedHeaders = request.headers;
        // ignore: close_sinks
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {}, onError: (_) {}, onDone: () {});
      });

      final uri = Uri.parse('ws://${server.address.host}:${server.port}/');
      final adapter = _IODartAdapter();

      final socket = await connectViaAdapter(
        adapter,
        uri,
        headers: {'Authorization': 'Bearer token123'},
      );
      addTearDown(() => socket.close().catchError((_) {}));

      expect(socket, isA<ws.WebSocket>());
      expect(adapter.lastUri, equals(uri.toString()));
      expect(adapter.lastHeaders?['Authorization'], equals('Bearer token123'));
      expect(receivedHeaders, isNotNull);
      expect(
          receivedHeaders!.value('authorization'), equals('Bearer token123'));
    });
  });
}
