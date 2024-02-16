// Copyright (C) 2017 Potix Corporation. All Rights Reserved
// History: 26/04/2017
// Author: jumperchen<jumperchen@potix.com>

import 'dart:async';
import 'dart:html';
import 'package:logging/logging.dart';
import 'package:socket_io_client/src/engine/transport.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart';

class WebSocketTransport extends Transport {
  static final Logger _logger =
      Logger('socket_io_client:transport.WebSocketTransport');

  @override
  String? name = 'websocket';
  WebSocket? ws;

  WebSocketTransport(Map opts) : super(opts) {
    var forceBase64 = opts['forceBase64'] ?? false;
    supportsBinary = !forceBase64;
  }

  @override
  void doOpen() {
    var uri = this.uri();
    var protocols = opts['protocols'];
    if (opts.containsKey('extraHeaders')) {
      opts['headers'] = opts['extraHeaders'];
    }

    try {
      ws = WebSocket(uri, protocols);
    } catch (err) {
      return emitReserved('error', err);
    }

    if (ws!.binaryType == null) {
      supportsBinary = false;
    }

    ws!.binaryType = socket!.binaryType;

    addEventListeners();
  }

  /// Adds event listeners to the socket
  ///
  /// @api private
  void addEventListeners() {
    ws!
      ..onOpen.listen((_) => onOpen())
      ..onClose.listen((closeEvent) => onClose({
        'description': "websocket connection closed",
        'context': closeEvent,
      }))
      ..onMessage.listen((MessageEvent evt) => onData(evt.data))
      ..onError.listen((e) {
        onError('websocket error', e);
      });
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
          // TypeError is thrown when passing the second argument on Safari
          ws!.send(data);
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
    ws?.close();
    ws = null;
  }

  /// Generates uri for connection.
  ///
  /// @api private
  String uri() {
    var query = this.query ?? {};
    var schema = opts['secure'] ? 'wss' : 'ws';
    // append timestamp to URI
    if (opts['timestampRequests'] == true) {
      query[opts['timestampRequests']] =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    }

    // communicate binary support capabilities
    if (supportsBinary == false) {
      query['b64'] = 1;
    }
    return createUri(schema, query);
  }
}
