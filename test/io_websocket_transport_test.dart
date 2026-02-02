import 'package:test/test.dart';
import 'package:socket_io_client/src/engine/transport/websocket_transport.dart';

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
  });
}
