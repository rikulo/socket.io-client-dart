import 'package:test/test.dart';
import 'package:socket_io_client/src/darty.dart';

void main() {
  group('OptionBuilder', () {
    test('build() returns empty map by default', () {
      final opts = OptionBuilder().build();
      expect(opts, isEmpty);
    });

    group('withCredentials', () {
      test('enableWithCredentials sets withCredentials to true', () {
        final opts = OptionBuilder().enableWithCredentials().build();
        expect(opts['withCredentials'], isTrue);
      });

      test('disableWithCredentials sets withCredentials to false', () {
        final opts = OptionBuilder()
            .enableWithCredentials()
            .disableWithCredentials()
            .build();
        expect(opts['withCredentials'], isFalse);
      });
    });

    group('forceNew', () {
      test('enableForceNew sets forceNew to true', () {
        final opts = OptionBuilder().enableForceNew().build();
        expect(opts['forceNew'], isTrue);
      });

      test('disableForceNew removes forceNew key', () {
        final opts =
            OptionBuilder().enableForceNew().disableForceNew().build();
        expect(opts.containsKey('forceNew'), isFalse);
      });
    });

    group('multiplex', () {
      test('enableMultiplex sets multiplex to true', () {
        final opts = OptionBuilder().enableMultiplex().build();
        expect(opts['multiplex'], isTrue);
      });

      test('disableMultiplex removes multiplex key', () {
        final opts =
            OptionBuilder().enableMultiplex().disableMultiplex().build();
        expect(opts.containsKey('multiplex'), isFalse);
      });
    });

    group('trailingSlash', () {
      test('enableAddTrailingSlash sets addTrailingSlash to true', () {
        final opts = OptionBuilder().enableAddTrailingSlash().build();
        expect(opts['addTrailingSlash'], isTrue);
      });

      test('disableAddTrailingSlash sets addTrailingSlash to false', () {
        final opts = OptionBuilder().disableAddTrailingSlash().build();
        expect(opts['addTrailingSlash'], isFalse);
      });
    });

    group('autoConnect', () {
      test('disableAutoConnect sets autoConnect to false', () {
        final opts = OptionBuilder().disableAutoConnect().build();
        expect(opts['autoConnect'], isFalse);
      });

      test('enableAutoConnect removes autoConnect key (defaults to true)', () {
        final opts = OptionBuilder()
            .disableAutoConnect()
            .enableAutoConnect()
            .build();
        expect(opts.containsKey('autoConnect'), isFalse);
      });
    });

    group('reconnection', () {
      test('disableReconnection sets reconnection to false', () {
        final opts = OptionBuilder().disableReconnection().build();
        expect(opts['reconnection'], isFalse);
      });

      test('enableReconnection removes reconnection key (defaults to true)', () {
        final opts = OptionBuilder()
            .disableReconnection()
            .enableReconnection()
            .build();
        expect(opts.containsKey('reconnection'), isFalse);
      });

      test('setReconnectionAttempts stores the value', () {
        final opts = OptionBuilder().setReconnectionAttempts(5).build();
        expect(opts['reconnectionAttempts'], equals(5));
      });

      test('setReconnectionDelay stores the value', () {
        final opts = OptionBuilder().setReconnectionDelay(2000).build();
        expect(opts['reconnectionDelay'], equals(2000));
      });

      test('setReconnectionDelayMax stores the value', () {
        final opts = OptionBuilder().setReconnectionDelayMax(10000).build();
        expect(opts['reconnectionDelayMax'], equals(10000));
      });

      test('setRandomizationFactor stores the value', () {
        final opts = OptionBuilder().setRandomizationFactor(0.3).build();
        expect(opts['randomizationFactor'], equals(0.3));
      });
    });

    group('timeout', () {
      test('setTimeout stores the value', () {
        final opts = OptionBuilder().setTimeout(5000).build();
        expect(opts['timeout'], equals(5000));
      });

      test('setAckTimeout stores the value', () {
        final opts = OptionBuilder().setAckTimeout(3000).build();
        expect(opts['ackTimeout'], equals(3000));
      });
    });

    group('path and query', () {
      test('setPath stores the value', () {
        final opts = OptionBuilder().setPath('/custom').build();
        expect(opts['path'], equals('/custom'));
      });

      test('setQuery stores the map', () {
        final query = {'token': 'abc123'};
        final opts = OptionBuilder().setQuery(query).build();
        expect(opts['query'], equals(query));
      });
    });

    group('transports', () {
      test('setTransports stores the list', () {
        final opts =
            OptionBuilder().setTransports(['websocket']).build();
        expect(opts['transports'], equals(['websocket']));
      });

      test('setUpgrade stores the value', () {
        final opts = OptionBuilder().setUpgrade(false).build();
        expect(opts['upgrade'], isFalse);
      });

      test('setRememberUpgrade stores the value', () {
        final opts = OptionBuilder().setRememberUpgrade(true).build();
        expect(opts['rememberUpgrade'], isTrue);
      });
    });

    group('headers and auth', () {
      test('setExtraHeaders stores the map', () {
        final headers = {'Authorization': 'Bearer token'};
        final opts = OptionBuilder().setExtraHeaders(headers).build();
        expect(opts['extraHeaders'], equals(headers));
      });

      test('setAuth stores the map', () {
        final auth = {'token': 'secret'};
        final opts = OptionBuilder().setAuth(auth).build();
        expect(opts['auth'], equals(auth));
      });

      test('setAuthFn stores the callback', () {
        void authFn(void Function(Map) cb) => cb({'token': 'x'});
        final opts = OptionBuilder().setAuthFn(authFn).build();
        expect(opts['auth'], isA<Function>());
      });
    });

    group('miscellaneous', () {
      test('setProtocols stores the list', () {
        final opts =
            OptionBuilder().setProtocols(['wss']).build();
        expect(opts['protocols'], equals(['wss']));
      });

      test('setTimestampParam stores the value', () {
        final opts = OptionBuilder().setTimestampParam('ts').build();
        expect(opts['timestampParam'], equals('ts'));
      });

      test('setTimestampRequests stores the value', () {
        final opts = OptionBuilder().setTimestampRequests(false).build();
        expect(opts['timestampRequests'], isFalse);
      });

      test('setRetries stores the value', () {
        final opts = OptionBuilder().setRetries(3).build();
        expect(opts['retries'], equals(3));
      });

      test('setForceBase64 stores the value', () {
        final opts = OptionBuilder().setForceBase64(true).build();
        expect(opts['forceBase64'], isTrue);
      });

      test('setTransportOptions stores the map', () {
        final transportOpts = {'websocket': {'timeout': 5000}};
        final opts =
            OptionBuilder().setTransportOptions(transportOpts).build();
        expect(opts['transportOptions'], equals(transportOpts));
      });
    });

    group('builder chaining', () {
      test('multiple options can be chained together', () {
        final opts = OptionBuilder()
            .disableAutoConnect()
            .setPath('/my-socket')
            .setTransports(['websocket'])
            .setReconnectionAttempts(3)
            .setTimeout(10000)
            .setExtraHeaders({'X-Custom': 'header'})
            .build();

        expect(opts['autoConnect'], isFalse);
        expect(opts['path'], equals('/my-socket'));
        expect(opts['transports'], equals(['websocket']));
        expect(opts['reconnectionAttempts'], equals(3));
        expect(opts['timeout'], equals(10000));
        expect(opts['extraHeaders'], equals({'X-Custom': 'header'}));
      });
    });
  });
}
