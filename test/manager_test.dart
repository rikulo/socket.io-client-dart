import 'package:test/test.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:web_socket/web_socket.dart' as ws;

void main() {
  group('Manager', () {
    test('Should pass the custom webSocketConnector to transport options', () {
      Future<ws.WebSocket> mockConnector(Uri uri,
          {Iterable<String>? protocols, Map<String, String>? headers}) async {
        return ws.WebSocket.connect(uri, protocols: protocols);
      }

      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'webSocketConnector': mockConnector},
      );

      final transportOptions = manager.options?['transportOptions'];
      expect(transportOptions, isNotNull);
      expect(transportOptions['websocket']['webSocketConnector'],
          equals(mockConnector));
    });

    test('Should not set transport options if no webSocketConnector is provided',
        () {
      final manager = Manager(uri: 'http://localhost:3000');

      final transportOptions = manager.options?['transportOptions'];
      // transportOptions should be null when no connector is provided
      expect(transportOptions, isNull);
    });
  });
}
