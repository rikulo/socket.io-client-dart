import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/engine/transport/http_client_adapter.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  group('Manager', () {
    test('Should pass the custom HttpClientAdapter to transport options', () {
      final mockAdapter = MockHttpClientAdapter();
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'httpClientAdapter': mockAdapter},
      );

      final transportOptions = manager.options?['transportOptions'];
      expect(transportOptions, isNotNull);
      expect(transportOptions['websocket']['httpClientAdapter'],
          equals(mockAdapter));
    });

    test('Should use the default HttpClientAdapter if none is provided', () {
      final manager = Manager(uri: 'http://localhost:3000');

      final transportOptions = manager.options?['transportOptions'];
      expect(transportOptions, isNotNull);
      expect(transportOptions['websocket']['httpClientAdapter'], isNotNull);
      expect(transportOptions['websocket']['httpClientAdapter'],
          isA<HttpClientAdapter>());
    });
  });
}
