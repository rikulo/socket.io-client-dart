import 'package:test/test.dart';
import 'package:socket_io_client/src/darty.dart';
import 'package:web_socket/web_socket.dart' as ws;

void main() {
  group('OptionBuilder', () {
    test('Should configure the custom WebSocketConnector', () {
      Future<ws.WebSocket> customConnector(Uri uri,
          {Iterable<String>? protocols, Map<String, String>? headers}) async {
        return ws.WebSocket.connect(uri, protocols: protocols);
      }

      final options =
          OptionBuilder().setWebSocketConnector(customConnector).build();

      expect(options['webSocketConnector'], equals(customConnector));
    });

    test('Should build options correctly without WebSocketConnector', () {
      final options = OptionBuilder().build();

      expect(options.containsKey('webSocketConnector'), isFalse);
    });
  });
}
