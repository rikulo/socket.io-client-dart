import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/src/engine/transport/http_client_adapter.dart';
import 'package:socket_io_client/src/engine/transport/http_client_adapter_factory.dart'
    show createPlatformHttpClientAdapter;

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  group('HttpClientAdapter', () {
    test('Should create the correct platform-specific adapter', () {
      final adapter = createPlatformHttpClientAdapter();
      expect(adapter, isA<HttpClientAdapter>());
    });

    test('Should call connect on the adapter with correct parameters',
        () async {
      final mockAdapter = MockHttpClientAdapter();
      const uri = 'wss://example.com/socket.io/';
      final headers = {'Authorization': 'Bearer token'};

      when(() => mockAdapter.connect(uri, headers: headers))
          .thenAnswer((_) async => 'Mock WebSocket Connection');

      final result = await mockAdapter.connect(uri, headers: headers);

      expect(result, equals('Mock WebSocket Connection'));
      verify(() => mockAdapter.connect(uri, headers: headers)).called(1);
    });
  });
}
