import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/src/engine/transport/websocket_transport.dart';
import 'package:web_socket/web_socket.dart' as ws;

class MockWebSocket extends Mock implements ws.WebSocket {}

void main() {
  group('WebSocketTransport', () {
    test('Should generate the URI correctly', () {
      final options = {
        'secure': true,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
        'timestampRequests': true,
        'timestampParam': 't',
      };

      final transport = WebSocketTransport(options);
      final uri = transport.uri();

      expect(uri, startsWith('wss://localhost:3000/socket.io/'));
      expect(uri, contains('t='));
    });

    test('Should generate http URI when not secure', () {
      final options = {
        'secure': false,
        'hostname': 'localhost',
        'port': 8080,
        'path': '/socket.io/',
        'timestampRequests': false,
      };

      final transport = WebSocketTransport(options);
      final uri = transport.uri();

      expect(uri, startsWith('ws://localhost:8080/socket.io/'));
    });

    test('Should set supportsBinary based on forceBase64', () {
      final optionsWithBase64 = {
        'forceBase64': true,
        'secure': false,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
      };

      final transportWithBase64 = WebSocketTransport(optionsWithBase64);
      expect(transportWithBase64.supportsBinary, isFalse);

      final optionsWithoutBase64 = {
        'forceBase64': false,
        'secure': false,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
      };

      final transportWithoutBase64 = WebSocketTransport(optionsWithoutBase64);
      expect(transportWithoutBase64.supportsBinary, isTrue);
    });

    test('Should pass headers and protocols to webSocketConnector', () async {
      Uri? capturedUri;
      Iterable<String>? capturedProtocols;
      Map<String, String>? capturedHeaders;

      final mockWs = MockWebSocket();
      when(() => mockWs.events).thenAnswer((_) => const Stream.empty());

      Future<ws.WebSocket> testConnector(
        Uri uri, {
        Iterable<String>? protocols,
        Map<String, String>? headers,
      }) async {
        capturedUri = uri;
        capturedProtocols = protocols;
        capturedHeaders = headers;
        return mockWs;
      }

      final options = {
        'secure': true,
        'hostname': 'example.com',
        'port': 443,
        'path': '/socket.io/',
        'timestampRequests': false,
        'protocols': ['proto1', 'proto2'],
        'extraHeaders': {'Authorization': 'Bearer token', 'X-Custom': 'value'},
        'webSocketConnector': testConnector,
      };

      final transport = WebSocketTransport(options);
      transport.doOpen();

      // Wait for async doOpen to complete
      await Future.delayed(Duration.zero);

      expect(capturedUri, isNotNull);
      expect(capturedUri.toString(), equals('wss://example.com/socket.io/'));
      expect(capturedProtocols, equals(['proto1', 'proto2']));
      expect(capturedHeaders,
          equals({'Authorization': 'Bearer token', 'X-Custom': 'value'}));
    });

    test('Should pass null headers when extraHeaders not set', () async {
      Map<String, String>? capturedHeaders;
      bool connectorCalled = false;

      final mockWs = MockWebSocket();
      when(() => mockWs.events).thenAnswer((_) => const Stream.empty());

      Future<ws.WebSocket> testConnector(
        Uri uri, {
        Iterable<String>? protocols,
        Map<String, String>? headers,
      }) async {
        connectorCalled = true;
        capturedHeaders = headers;
        return mockWs;
      }

      final options = {
        'secure': false,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
        'timestampRequests': false,
        'webSocketConnector': testConnector,
      };

      final transport = WebSocketTransport(options);
      transport.doOpen();

      await Future.delayed(Duration.zero);

      expect(connectorCalled, isTrue);
      expect(capturedHeaders, isNull);
    });

    test('Should discard the socket if closed while still connecting',
        () async {
      final connectCompleter = Completer<ws.WebSocket>();
      final mockWs = MockWebSocket();
      when(() => mockWs.close()).thenAnswer((_) async {});

      Future<ws.WebSocket> slowConnector(
        Uri uri, {
        Iterable<String>? protocols,
        Map<String, String>? headers,
      }) =>
          connectCompleter.future;

      final options = {
        'secure': false,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
        'timestampRequests': false,
        'webSocketConnector': slowConnector,
      };

      final transport = WebSocketTransport(options);
      var openEmitted = false;
      transport.on('open', (_) => openEmitted = true);

      // Start connecting, then close before the connection resolves.
      transport.open();
      transport.close();
      expect(transport.readyState, equals('closed'));

      // The connection now resolves after the transport was already closed.
      connectCompleter.complete(mockWs);
      await Future.delayed(Duration.zero);

      // The late socket must be closed and discarded, with no spurious 'open'
      // and no event subscription on the resurrected transport.
      verify(() => mockWs.close()).called(1);
      verifyNever(() => mockWs.events);
      expect(openEmitted, isFalse);
      expect(transport.readyState, equals('closed'));
    });
  });
}
