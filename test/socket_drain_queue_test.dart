import 'package:test/test.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/socket.dart';

void main() {
  group('Socket._drainQueue()', () {
    late Socket socket;

    setUp(() {
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'autoConnect': false, 'retries': 3},
      );
      socket = Socket(manager, '/', {'autoConnect': false});
    });

    test('does not throw when queued event has no arguments', () {
      // Simulates emitting an event with no data while retries is set.
      // Previously crashed with "Bad state: No element" because _drainQueue
      // called args.last unconditionally on an empty list after removeAt(0).
      expect(
        () => socket.emitWithAck('ping', null),
        returnsNormally,
      );
    });

    test('does not throw when queued event has data but no ack callback', () {
      expect(
        () => socket.emitWithAck('chat', 'hello'),
        returnsNormally,
      );
    });

    test('does not throw when queued event has an ack callback', () {
      expect(
        () => socket.emitWithAck('chat', 'hello', ack: (response) {}),
        returnsNormally,
      );
    });
  });
}
