// Copyright (C) 2019 Potix Corporation. All Rights Reserved
// History: 2019-01-21 12:27
// Author: jumperchen<jumperchen@potix.com>
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:socket_io_client/src/engine/socket.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';

abstract class Transport extends EventEmitter {
  static final Logger _logger = Logger('socket_io_client:Transport');

  Map<String, dynamic>? query;
  bool? writable;

  late Map opts;
  bool? supportsBinary;
  String? readyState;
  Socket? socket;

  Transport(this.opts) {
    query = opts['query'];
    readyState = '';
    socket = opts['socket'];
  }

  ///
  /// Emits an error.
  ///
  /// @param {String} str
  /// @return {Transport} for chaining
  onError(msg, [desc]) {
    super.emitReserved(
        'error', {'msg': msg, 'desc': desc, 'type': 'TransportError'});
    return this;
  }

  ///
  /// Opens the transport.
  ///
  open() {
    readyState = 'opening';
    doOpen();
    return this;
  }

  ///
  /// Closes the transport.
  ///
  close() {
    if ('opening' == readyState || 'open' == readyState) {
      doClose();
      onClose();
    }
    return this;
  }

  ///
  /// Sends multiple packets.
  ///
  /// @param {Array} packets
  void send(List packets) {
    if ('open' == readyState) {
      write(packets);
    } else {
      // this might happen if the transport was silently closed in the beforeunload event handler
      _logger.fine("transport is not open, discarding packets");
    }
  }

  ///
  /// Called upon open
  ///
  /// @api private
  void onOpen() {
    readyState = 'open';
    writable = true;
    emitReserved('open');
  }

  ///
  /// Called with data.
  ///
  /// @param {String} data
  /// @api private
  void onData(data) {
    var packet = PacketParser.decodePacket(data, socket!.binaryType);
    onPacket(packet);
  }

  ///
  /// Called with a decoded packet.
  void onPacket(packet) {
    emitReserved('packet', packet);
  }

  ///
  /// Called upon close.
  ///
  /// @api private
  void onClose([dynamic details]) {
    readyState = 'closed';
    emitReserved('close', details);
  }

  get name;

  void pause(Function() onPause) {}

  String createUri(String schema, Map<String, dynamic> query) {
    return '$schema://${_hostname()}${_port()}${opts["path"]}${_query(query)}';
  }

  String _hostname() {
    final hostname = opts["hostname"] as String;
    return hostname.contains(":") ? "[$hostname]" : hostname;
  }

  String _port() {
    final rawPort = opts["port"];

    // Convert port to int if it's a string
    int? port;
    if (rawPort is int) {
      port = rawPort;
    } else if (rawPort is String) {
      port = int.tryParse(rawPort);
    }

    // Determine default port for the scheme
    final defaultPort = opts["secure"] == true ? 443 : 80;

    // Only include port if it's specified and different from the default port
    // Default ports (443 for HTTPS, 80 for HTTP) should be omitted from URIs
    if (port != null && port != 0 && port != defaultPort) {
      return ":$port";
    }

    return "";
  }

  String _query(Map<String, dynamic> query) {
    Map<String, String> result = {};
    query.forEach((key, value) {
      if (value is String) {
        result[key] = value;
      } else {
        // Use jsonEncode for complex types like List or Map
        result[key] = jsonEncode(value);
      }
    });
    final queryString = Uri(queryParameters: result).query;
    return queryString.isNotEmpty ? "?$queryString" : "";
  }

  void write(List data);
  void doOpen();
  void doClose();
}
