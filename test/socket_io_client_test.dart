import 'dart:async';

import 'package:test/test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:web_socket/web_socket.dart' as ws;
import 'package:web_socket/testing.dart';

void main() {
  group('Socket.IO Client', () {
    test('Should connect and receive events', () async {
      final (clientWs, serverWs) = fakes();
      final connectedCompleter = Completer<void>();
      final messageCompleter = Completer<String>();

      // Create socket with custom connector that returns our fake WebSocket
      final socket = io.io(
        'http://localhost:3000',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableReconnection()
            .enableForceNew() // Avoid socket caching
            .setWebSocketConnector((uri, {protocols, headers}) async {
              return clientWs;
            })
            .build(),
      );

      socket.onConnect((_) {
        if (!connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        }
      });

      socket.on('message', (data) {
        if (!messageCompleter.isCompleted) {
          messageCompleter.complete(data as String);
        }
      });

      // Simulate server-side protocol
      unawaited(_simulateServer(serverWs, onEvent: (event, data) {
        if (event == 'hello') {
          // Echo back as 'message' event
          _sendSocketIOEvent(serverWs, 'message', 'Hello from server!');
        }
      }));

      // Wait for connection
      await connectedCompleter.future.timeout(const Duration(seconds: 5));
      expect(socket.connected, isTrue);

      // Send a message
      socket.emit('hello', 'world');

      // Wait for response
      final response =
          await messageCompleter.future.timeout(const Duration(seconds: 5));
      expect(response, equals('Hello from server!'));

      socket.dispose();
    });

    test('Should pass extraHeaders to connector', () async {
      final (clientWs, serverWs) = fakes();
      Map<String, String>? receivedHeaders;
      final connectedCompleter = Completer<void>();

      final socket = io.io(
        'http://localhost:3000',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableReconnection()
            .enableForceNew()
            .setExtraHeaders({'Authorization': 'Bearer test-token'})
            .setWebSocketConnector((uri, {protocols, headers}) async {
              receivedHeaders = headers;
              return clientWs;
            })
            .build(),
      );

      socket.onConnect((_) {
        if (!connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        }
      });

      // Simulate server
      unawaited(_simulateServer(serverWs));

      await connectedCompleter.future.timeout(const Duration(seconds: 5));

      expect(receivedHeaders, isNotNull);
      expect(receivedHeaders!['Authorization'], equals('Bearer test-token'));

      socket.dispose();
    });

    test('Should handle disconnect', () async {
      final (clientWs, serverWs) = fakes();
      final connectedCompleter = Completer<void>();
      final disconnectedCompleter = Completer<void>();

      final socket = io.io(
        'http://localhost:3000',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableReconnection()
            .enableForceNew()
            .setWebSocketConnector((uri, {protocols, headers}) async {
              return clientWs;
            })
            .build(),
      );

      socket.onConnect((_) {
        if (!connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        }
      });

      socket.onDisconnect((_) {
        if (!disconnectedCompleter.isCompleted) {
          disconnectedCompleter.complete();
        }
      });

      // Simulate server
      unawaited(_simulateServer(serverWs));

      await connectedCompleter.future.timeout(const Duration(seconds: 5));
      expect(socket.connected, isTrue);

      // Disconnect from client side
      socket.dispose();

      await disconnectedCompleter.future.timeout(const Duration(seconds: 5));
      expect(socket.connected, isFalse);
    });
  });
}

/// Simulates a Socket.IO server using Engine.IO + Socket.IO protocol
Future<void> _simulateServer(
  ws.WebSocket serverWs, {
  void Function(String event, dynamic data)? onEvent,
}) async {
  // Send Engine.IO open packet
  serverWs.sendText(
      '0{"sid":"test-session-id","upgrades":[],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}');

  try {
    await for (final event in serverWs.events) {
      switch (event) {
        case ws.TextDataReceived(:final text):
          _handleClientMessage(serverWs, text, onEvent);
        case ws.BinaryDataReceived():
          // Handle binary if needed
          break;
        case ws.CloseReceived():
          return;
      }
    }
  } catch (_) {
    // Socket closed
  }
}

void _handleClientMessage(
  ws.WebSocket serverWs,
  String message,
  void Function(String event, dynamic data)? onEvent,
) {
  if (message.isEmpty) return;

  final engineType = message[0];

  // Engine.IO message (type 4) contains Socket.IO packet
  if (engineType == '4') {
    final socketIOPacket = message.substring(1);
    if (socketIOPacket.isEmpty) return;

    final socketIOType = socketIOPacket[0];

    // Socket.IO CONNECT (type 0)
    if (socketIOType == '0') {
      // Send connect acknowledgment
      serverWs.sendText('40{"sid":"socket-session-id"}');
    }
    // Socket.IO EVENT (type 2)
    else if (socketIOType == '2') {
      // Parse event: 2["eventName", data]
      final jsonPart = socketIOPacket.substring(1);
      if (jsonPart.startsWith('[')) {
        // Simple parsing for test purposes
        final match = RegExp(r'\["(\w+)"(?:,(.+))?\]').firstMatch(jsonPart);
        if (match != null) {
          final eventName = match.group(1)!;
          final data = match.group(2);
          onEvent?.call(eventName, data?.replaceAll('"', ''));
        }
      }
    }
  }
  // Engine.IO ping (type 2) - respond with pong (type 3)
  else if (engineType == '2') {
    serverWs.sendText('3');
  }
}

void _sendSocketIOEvent(ws.WebSocket serverWs, String event, dynamic data) {
  // Engine.IO message (4) + Socket.IO event (2) + JSON array
  final dataStr = data is String ? '"$data"' : data.toString();
  serverWs.sendText('42["$event",$dataStr]');
}
