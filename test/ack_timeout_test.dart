import 'package:test/test.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/socket.dart';

void main() {
  group('Socket ack with timeout (#441)', () {
    late Socket socket;

    setUp(() {
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'autoConnect': false},
      );
      // ackTimeout makes _registerAckCallback wrap the ack with the error-first
      // timeout wrapper, which is the path that used to crash on empty acks.
      socket =
          Socket(manager, '/', {'autoConnect': false, 'ackTimeout': 5000});
    });

    test('empty server ack completes (was NoSuchMethodError)', () async {
      final future = socket.emitWithAckAsync('ping', {});
      // Server replies with ack() carrying no payload.
      socket.onack({'id': '0', 'data': <dynamic>[]});
      expect(await future, isNull);
    });

    test('onack with empty data does not throw', () {
      socket.emitWithAckAsync('ping', {});
      expect(
        () => socket.onack({'id': '0', 'data': <dynamic>[]}),
        returnsNormally,
      );
    });

    test('single-value ack still forwards the value (no side effect)',
        () async {
      final future = socket.emitWithAckAsync('ping', {});
      socket.onack({'id': '0', 'data': <dynamic>['pong']});
      expect(await future, equals('pong'));
    });

    test('multi-value ack still forwards all values (no side effect)', () {
      final received = <dynamic>[];
      // Lower-level ack accepting the error slot plus the spread values.
      socket.emitWithAck('ping', {}, ack: (err, [a, b, c]) {
        received.addAll([err, a, b, c]);
      });
      socket.onack({'id': '0', 'data': <dynamic>[1, 2, 3]});
      expect(received, equals([null, 1, 2, 3]));
    });
  });
}
