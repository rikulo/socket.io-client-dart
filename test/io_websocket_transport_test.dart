import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/src/engine/transport/io_websocket_transport.dart';
import 'package:socket_io_client/src/engine/transport/http_client_adapter.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

class MockWebSocket extends Mock {}

void main() {
  group('IOWebSocketTransport', () {
    test('Should use the custom HttpClientAdapter if provided', () async {
      final mockAdapter = MockHttpClientAdapter();
      final options = {
        'httpClientAdapter': mockAdapter,
        'secure': true,
        'hostname': 'example.com',
        'port': 443,
        'path': '/socket.io/',
        'timestampRequests': true,
        'timestampParam': 't',
      };

      final transport = IOWebSocketTransport(options);

      when(() => mockAdapter.connect(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => MockWebSocket());

      transport.doOpen();

      verify(() => mockAdapter.connect(any(), headers: any(named: 'headers')))
          .called(1);
    });

    test('Should generate the URI correctly', () {
      final options = {
        'secure': true,
        'hostname': 'localhost',
        'port': 3000,
        'path': '/socket.io/',
        'timestampRequests': true,
        'timestampParam': 't',
      };

      final transport = IOWebSocketTransport(options);
      final uri = transport.uri();

      expect(uri, startsWith('wss://localhost:3000/socket.io/'));
      expect(uri, contains('t='));
    });
  });
}
