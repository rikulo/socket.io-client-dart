/**
 * websocket_transport.dart
 *
 * Purpose:
 *
 * Description:
 *
 * History:
 *   26/04/2017, Created by jumperchen
 *
 * Copyright (C) 2017 Potix Corporation. All Rights Reserved.
 */
import 'dart:async';
import 'dart:html';
import 'package:logging/logging.dart';
import 'package:socket_io/src/engine/parser/parser.dart';
import 'package:socket_io_client/src/engine/parseqs.dart';
import 'package:socket_io_client/src/engine/transport/transports.dart';

class WebSocketTransport extends Transport {
  static Logger _logger = new Logger('socket_io_client:transport.WebSocketTransport');

  String name = 'websocket';
  var protocols;

  bool supportsBinary;
  Map perMessageDeflate;
  WebSocket ws;

  WebSocketTransport(Map opts) : super(opts) {
    var forceBase64 = (opts != null && opts['forceBase64']);
    if (forceBase64) {
      this.supportsBinary = false;
    }
    this.perMessageDeflate = opts['perMessageDeflate'];
    this.protocols = opts['protocols'];
  }

  void doOpen() {
//    if (!this.check()) {
//      // let probe timeout
//      return null;
//    }

    var uri = this.uri();
    var protocols = this.protocols;
    var opts = {
      'agent': this.agent,
      'perMessageDeflate': this.perMessageDeflate
    };

//    // SSL options for Node.js client
//    opts.pfx = this.pfx;
//    opts.key = this.key;
//    opts.passphrase = this.passphrase;
//    opts.cert = this.cert;
//    opts.ca = this.ca;
//    opts.ciphers = this.ciphers;
//    opts.rejectUnauthorized = this.rejectUnauthorized;
//    if (this.extraHeaders) {
//      opts.headers = this.extraHeaders;
//    }
//    if (this.localAddress) {
//      opts.localAddress = this.localAddress;
//    }

    try {
      this.ws = new WebSocket(uri, protocols);
    } catch (err) {
      return this.emit('error', err);
    }

    if (this.ws.binaryType == null) {
      this.supportsBinary = false;
    }

//    if (this.ws.supports && this.ws.supports.binary) {
//      this.supportsBinary = true;
//      this.ws.binaryType = 'nodebuffer';
//    } else {
      this.ws.binaryType = 'arraybuffer';
//    }

    this.addEventListeners();
  }

  /**
   * Adds event listeners to the socket
   *
   * @api private
   */
  void addEventListeners() {
    this.ws..onOpen.listen((_) => onOpen())
      ..onClose.listen((_) => onClose())
      ..onMessage.listen((MessageEvent evt) => onData(evt.data))
      ..onError.listen((e) {
        onError('websocket error');
      });
  }

  /**
   * Writes data to socket.
   *
   * @param {Array} array of packets.
   * @api private
   */
  write(List packets) {
    this.writable = false;


    var done = () {
      emit('flush');

      // fake drain
      // defer to next tick to allow Socket to clear writeBuffer
      Timer.run(() {
        writable = true;
        emit('drain');
      });
    };

    int total = packets.length;
    // encodePacket efficient as it uses WS framing
    // no need for encodePayload
    packets.forEach((packet) {
      PacketParser.encodePacket(packet, supportsBinary: supportsBinary, callback: (data) {

      // Sometimes the websocket has already been closed but the browser didn't
      // have a chance of informing us about it yet, in that case send will
      // throw an error
      try {
      // TypeError is thrown when passing the second argument on Safari
        ws.send(data);
      } catch (e) {
        _logger.fine('websocket closed before onclose event');
      }

      if (--total == 0)
        done();
      });
    });

  }

  /**
   * Closes socket.
   *
   * @api private
   */
  doClose() {
    this.ws?.close();
  }

  /**
   * Generates uri for connection.
   *
   * @api private
   */
  uri() {
    var query = this.query ?? {};
    var schema = this.secure ? 'wss' : 'ws';
    var port = '';

    // avoid port if default for schema
    if (this.port != null && (('wss' == schema && this.port != 443) ||
        ('ws' == schema && this.port != 80))) {
      port = ':${this.port}';
    }

    // append timestamp to URI
    if (this.timestampRequests == true) {
      query[this.timestampParam] = new DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    }

    // communicate binary support capabilities
    if (this.supportsBinary == false) {
      query['b64'] = 1;
    }

    var queryString = encode(query);

    // prepend ? to query
    if (queryString.isNotEmpty) {
      queryString = '?$queryString';
    }

    var ipv6 = this.hostname.contains(':');
    return schema + '://' + (ipv6 ? '[' + this.hostname + ']' : this.hostname) + port + this.path + queryString;
  }
//
//  /**
//   * Feature detection for WebSocket.
//   *
//   * @return {Boolean} whether this transport is available.
//   * @api public
//   */
//  check() {
//    return !!WebSocket && !('__initialize' in WebSocket && this.name === WS.prototype.name);
//  }
}