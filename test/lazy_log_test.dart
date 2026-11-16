import 'package:logging/logging.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/socket.dart';
import 'package:test/test.dart';

class _CountingPayload {
  int stringified = 0;

  @override
  String toString() {
    stringified++;
    return 'payload';
  }
}

void main() {
  group('Payload log messages', () {
    late Socket socket;
    late _CountingPayload payload;

    setUp(() {
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'autoConnect': false},
      );
      socket = Socket(manager, '/', {'autoConnect': false});
      payload = _CountingPayload();
    });

    tearDown(() => Logger.root.level = Level.INFO);

    test('an ack does not stringify its payload while FINE is off', () {
      socket.emitWithAck('ping', {}, ack: (_) {});
      socket.onack({
        'id': '0',
        'data': <dynamic>[payload]
      });
      expect(payload.stringified, 0);
    });

    test('an ack still logs its payload once FINE is on', () {
      Logger.root.level = Level.FINE;
      socket.emitWithAck('ping', {}, ack: (_) {});
      socket.onack({
        'id': '0',
        'data': <dynamic>[payload]
      });
      expect(payload.stringified, greaterThan(0));
    });

    test('an event does not stringify its payload while FINE is off', () {
      socket.onevent({
        'data': <dynamic>['menu', payload]
      });
      expect(payload.stringified, 0);
    });
  });
}
