// Copyright (C) 2017 Potix Corporation. All Rights Reserved
// History: 26/04/2017
// Author: jumperchen<jumperchen@potix.com>

import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:socket_io_client/src/engine/transport.dart';
import 'package:socket_io_client/src/engine/transport/default_ws_connector.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart';
import 'package:web_socket/web_socket.dart' as ws;

/// Unified WebSocket transport using package:web_socket.
/// Works on both native (dart:io) and web platforms.
class WebSocketTransport extends Transport {
  static final Logger _logger =
      Logger('socket_io_client:transport.WebSocketTransport');

  @override
  String? name = 'websocket';
  ws.WebSocket? _ws;
  StreamSubscription<ws.WebSocketEvent>? _subscription;

  WebSocketTransport(Map opts) : super(opts) {
    var forceBase64 = opts['forceBase64'] ?? false;
    supportsBinary = !forceBase64;
  }

  @override
  void doOpen() async {
    var uri = this.uri();
    final ws.WebSocket socket;
    try {
      final connector = opts['webSocketConnector']
          as Future<ws.WebSocket> Function(Uri,
              {Iterable<String>? protocols, Map<String, String>? headers})?;
      final protocols = opts['protocols'] as Iterable<String>?;
      final headers = opts['extraHeaders'] as Map<String, String>?;

      if (connector != null) {
        socket = await connector(Uri.parse(uri),
            protocols: protocols, headers: headers);
      } else {
        // Use the platform default connector so that extraHeaders keep working
        // on native (dart:io) without requiring a custom webSocketConnector.
        socket = await connectWebSocket(Uri.parse(uri),
            protocols: protocols, headers: headers);
      }
    } catch (err) {
      return emit('error', err);
    }

    // doOpen() is async, so the transport may have been closed (e.g. a connect
    // timeout or a quick disconnect) while the connection was still pending.
    // In that case discard the freshly opened socket instead of resurrecting a
    // closed transport, which would otherwise leak the socket and fire a
    // spurious 'open' after 'close'.
    if (readyState == 'closed') {
      unawaited(socket.close().catchError((Object _) {}));
      return;
    }

    _ws = socket;
    _addEventListeners();
  }

  /// Adds event listeners to the socket
  ///
  /// @api private
  void _addEventListeners() {
    onOpen();
    _subscription = _ws!.events.listen((event) {
      switch (event) {
        case ws.TextDataReceived(:final text):
          onData(text);
        case ws.BinaryDataReceived(:final data):
          onData(data);
        case ws.CloseReceived():
          onClose();
      }
    }, onError: (_) => onError('websocket error'));
  }

  /// Writes data to socket.
  ///
  /// @param {Array} array of packets.
  /// @api private
  @override
  void write(List packets) {
    writable = false;

    var total = packets.length;
    // encodePacket efficient as it uses WS framing
    // no need for encodePayload
    for (var packet in packets) {
      PacketParser.encodePacket(packet,
          supportsBinary: supportsBinary!, fromClient: true, callback: (data) {
        // Sometimes the websocket has already been closed but the browser didn't
        // have a chance of informing us about it yet, in that case send will
        // throw an error
        try {
          if (data is String) {
            _ws?.sendText(data);
          } else if (data is ByteBuffer) {
            _ws?.sendBytes(data.asUint8List());
          } else if (data is List<int>) {
            _ws?.sendBytes(Uint8List.fromList(data));
          }
        } catch (e) {
          _logger.fine('websocket closed before onclose event');
        }

        if (--total == 0) {
          // fake drain
          // defer to next tick to allow Socket to clear writeBuffer
          Timer.run(() {
            writable = true;
            emitReserved('drain');
          });
        }
      });
    }
  }

  /// Closes socket.
  ///
  /// @api private
  @override
  void doClose() {
    _subscription?.cancel();
    _subscription = null;
    _ws?.close();
    _ws = null;
  }

  /// Generates uri for connection.
  ///
  /// @api private
  String uri() {
    var query = this.query ?? {};
    var schema = opts['secure'] ? 'wss' : 'ws';
    // append timestamp to URI
    if (opts['timestampRequests'] == true) {
      query[opts['timestampParam']] =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    }

    // communicate binary support capabilities
    if (supportsBinary == false) {
      query['b64'] = 1;
    }
    return createUri(schema, query);
  }
}
