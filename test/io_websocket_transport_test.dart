import 'dart:async';
import 'dart:typed_data';

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
      expect(capturedHeaders, equals({'Authorization': 'Bearer token', 'X-Custom': 'value'}));
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
  });
}
