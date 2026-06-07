@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart' as ws;
import 'package:socket_io_client/src/engine/transport/default_ws_connector.dart';

void main() {
  group('default native WebSocket connector', () {
    late HttpServer server;
    late Uri uri;
    HttpHeaders? receivedHeaders;

    setUp(() async {
      receivedHeaders = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      uri = Uri.parse('ws://${server.address.host}:${server.port}/');
      server.listen((request) async {
        receivedHeaders = request.headers;
        // Closed via server.close(force: true) in tearDown.
        // ignore: close_sinks
        final socket = await WebSocketTransformer.upgrade(request);
        // Keep the connection open; let the client drive the close.
        socket.listen((_) {}, onError: (_) {}, onDone: () {});
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('forwards extraHeaders to the handshake', () async {
      final socket = await connectWebSocket(
        uri,
        headers: {'Authorization': 'Bearer token123', 'X-Custom': 'value'},
      );
      addTearDown(() => socket.close().catchError((_) {}));

      expect(receivedHeaders, isNotNull);
      expect(
          receivedHeaders!.value('authorization'), equals('Bearer token123'));
      expect(receivedHeaders!.value('x-custom'), equals('value'));
    });

    test('connects fine when no headers are provided', () async {
      final socket = await connectWebSocket(uri);
      addTearDown(() => socket.close().catchError((_) {}));

      expect(receivedHeaders, isNotNull);
      expect(socket, isA<ws.WebSocket>());
    });
  });
}
