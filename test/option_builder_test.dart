import 'package:socket_io_client/src/engine/transport/http_client_adapter_factory.dart';
import 'package:test/test.dart';
import 'package:socket_io_client/src/darty.dart';

void main() {
  group('OptionBuilder', () {
    test('Should configure the custom HttpClientAdapter', () {
      final customHttpClientAdapter = createPlatformHttpClientAdapter();
      final options =
          OptionBuilder().setHttpClientAdapter(customHttpClientAdapter).build();

      expect(options['httpClientAdapter'], equals(customHttpClientAdapter));
    });

    test('Should build options correctly without HttpClientAdapter', () {
      final options = OptionBuilder().build();

      expect(options.containsKey('httpClientAdapter'), isFalse);
    });
  });
}
