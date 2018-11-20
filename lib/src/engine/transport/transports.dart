/**
 * transports.dart
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
import 'package:logging/logging.dart';
import 'package:socket_io/src/engine/parser/parser.dart';
import 'package:socket_io/src/util/event_emitter.dart';
import 'package:socket_io_client/src/engine/socket.dart';
import 'package:socket_io_client/src/engine/transport/jsonp_transport.dart';
import 'package:socket_io_client/src/engine/transport/websocket_transport.dart';
import 'package:socket_io_client/src/engine/transport/xhr_transport.dart';

class Transports {
  static List<String> upgradesTo(String from) {
    if ("polling" == from) {
      return ["websocket"];
    }
    return [];
  }

  static Transport newInstance(String name, options) {
    if ('websocket' == name) {
      return new WebSocketTransport(options);
    } else if ('polling' == name) {
      if (options['forceJSONP'] != true) {
        return new XHRTransport(options);
      } else {
        if (options['jsonp'] != false) return new JSONPTransport(options);
        throw new StateError('JSONP disabled');
      }
    } else {
      throw new UnsupportedError('Unknown transport $name');
    }
  }
}

abstract class Transport extends EventEmitter {
  static Logger _logger = new Logger('socket_io_client:transport.Transport');

  String path;
  String hostname;
  int port;
  bool secure;
  Map query;
  String timestampParam;
  bool timestampRequests;
  String readyState;
  bool agent;
  Socket socket;
  bool enablesXDR;
  bool writable;
  String name;
  bool supportsBinary;

  Transport(Map opts) {
    this.path = opts['path'];
    this.hostname = opts['hostname'];
    this.port = opts['port'];
    this.secure = opts['secure'];
    this.query = opts['query'];
    this.timestampParam = opts['timestampParam'];
    this.timestampRequests = opts['timestampRequests'];
    this.readyState = '';
    this.agent = opts['agent || false'];
    this.socket = opts['socket'];
    this.enablesXDR = opts['enablesXDR'];

    // SSL options for Node.js client
//    this.pfx = opts['x'];
//    this.key = opts['y'];
//    this.passphrase = opts['ssphrase'];
//    this.cert = opts['rt'];
//    this.ca = opts[''];
//    this.ciphers = opts['phers'];
//    this.rejectUnauthorized = opts['jectUnauthorized'];
//    this.forceNode = opts['rceNode'];
//
//    // other options for Node.js client
//    this.extraHeaders = opts['traHeaders'];
//    this.localAddress = opts['calAddress'];
  }

  /**
   * Emits an error.
   *
   * @param {String} str
   * @return {Transport} for chaining
   * @api public
   */
  void onError(msg, [desc]) {
    if (this.hasListeners('error')) {
      this.emit('error', {'msg': msg, 'desc': desc, 'type': 'TransportError'});
    } else {
      _logger.fine('ignored transport error $msg ($desc)');
    }
  }

  /**
   * Opens the transport.
   *
   * @api public
   */
  void open() {
    if ('closed' == this.readyState || '' == this.readyState) {
      this.readyState = 'opening';
      this.doOpen();
    }
  }

  /**
   * Closes the transport.
   *
   * @api private
   */
  void close() {
    if ('opening' == this.readyState || 'open' == this.readyState) {
      this.doClose();
      this.onClose();
    }
  }

  /**
   * Sends multiple packets.
   *
   * @param {Array} packets
   * @api private
   */
  send(List<Map> packets) {
    if ('open' == this.readyState) {
      this.write(packets);
    } else {
      throw new StateError('Transport not open');
    }
  }

  /**
   * Called upon open
   *
   * @api private
   */
  onOpen() {
    this.readyState = 'open';
    this.writable = true;
    this.emit('open');
  }

  /**
   * Called with data.
   *
   * @param {String} data
   * @api private
   */
  onData(data) {
    var packet =
        PacketParser.decodePacket(data, binaryType: this.socket.binaryType);
    this.onPacket(packet);
  }

  /**
   * Called with a decoded packet.
   */
  onPacket(Map packet) {
    this.emit('packet', packet);
  }

  /**
   * Called upon close.
   *
   * @api private
   */
  onClose() {
    this.readyState = 'closed';
    this.emit('close');
  }

  void write(List<Map> data);
  void doOpen();
  void doClose();
}
