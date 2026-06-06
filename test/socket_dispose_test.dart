import 'package:test/test.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/socket.dart';

void main() {
  group('Socket.dispose()', () {
    late Socket socket;

    setUp(() {
      final manager = Manager(
        uri: 'http://localhost:3000',
        options: {'autoConnect': false},
      );
      socket = Socket(manager, '/', {'autoConnect': false});
    });

    test('clears onAny listeners registered via onAny()', () {
      socket.onAny((event, data) {});
      socket.onAny((event, data) {});
      expect(socket.listenersAny(), hasLength(2));

      socket.dispose();

      expect(socket.listenersAny(), isEmpty);
    });

    test('clears onAnyOutgoing listeners registered via onAnyOutgoing()', () {
      socket.onAnyOutgoing((event, data) {});
      expect(socket.listenersAnyOutgoing(), hasLength(1));

      socket.dispose();

      expect(socket.listenersAnyOutgoing(), isEmpty);
    });

    test('clears both onAny and onAnyOutgoing together', () {
      socket.onAny((event, data) {});
      socket.onAnyOutgoing((event, data) {});

      socket.dispose();

      expect(socket.listenersAny(), isEmpty);
      expect(socket.listenersAnyOutgoing(), isEmpty);
    });

    test('dispose() is idempotent — safe to call multiple times', () {
      socket.onAny((event, data) {});
      socket.dispose();
      expect(() => socket.dispose(), returnsNormally);
      expect(socket.listenersAny(), isEmpty);
    });
  });
}
