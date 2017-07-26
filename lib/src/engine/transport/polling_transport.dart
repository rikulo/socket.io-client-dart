import 'package:socket_io_client/src/engine/parseqs.dart';
/**
 * polling_transport.dart
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
import 'package:socket_io_client/src/engine/transport/transports.dart';
import 'package:logging/logging.dart';
import 'package:socket_io/src/engine/parser/parser.dart';

final Logger _logger = new Logger('socket_io:transport.PollingTransport');

abstract class PollingTransport extends Transport {

  /**
   * Transport name.
   */
  String name = 'polling';

  bool supportsBinary;
  bool polling;

  /**
   * Polling interface.
   *
   * @param {Object} opts
   * @api private
   */
  PollingTransport(Map opts): super(opts) {
    var forceBase64 = (opts != null && opts['forceBase64']);
    if (/*!hasXHR2 || */forceBase64) {
      this.supportsBinary = false;
    }
  }


  /**
   * Opens the socket (triggers polling). We write a PING message to determine
   * when the transport is open.
   *
   * @api private
   */
  doOpen() {
    this.poll();
  }

  /**
   * Pauses polling.
   *
   * @param {Function} callback upon buffers are flushed and transport is paused
   * @api private
   */
  pause(onPause) {
    var self = this;

    this.readyState = 'pausing';

    var pause = () {
      _logger.fine('paused');
      self.readyState = 'paused';
      onPause();
    };

    if (this.polling == true || this.writable != true) {
      var total = 0;

      if (this.polling == true) {
        _logger.fine('we are currently polling - waiting to pause');
        total++;
        this.once('pollComplete', (_) {
        _logger.fine('pre-pause polling complete');
        if (--total == 0)
          pause();
        });
      }

      if (this.writable != true) {
        _logger.fine('we are currently writing - waiting to pause');
        total++;
        this.once('drain', (_) {
        _logger.fine('pre-pause writing complete');
        if (--total == 0)
          pause();
        });
      }
    } else {
      pause();
    }
  }

  /**
   * Starts polling cycle.
   *
   * @api public
   */
  poll() {
    _logger.fine('polling');
    this.polling = true;
    this.doPoll();
    this.emit('poll');
  }

  /**
   * Overloads onData to detect payloads.
   *
   * @api private
   */
  onData(data) {
    var self = this;
    _logger.fine('polling got data $data');
    var callback = (packet, [index, total]) {
      // if its the first message we consider the transport open
      if ('opening' == self.readyState) {
        self.onOpen();
      }

      // if its a close packet, we close the ongoing requests
      if ('close' == packet['type']) {
        self.onClose();
        return false;
      }

      // otherwise bypass onData and handle the message
      self.onPacket(packet);
    };

    // decode payload
    PacketParser.decodePayload(data, binaryType: this.socket.binaryType, callback: callback);

    // if an event did not trigger closing
    if ('closed' != this.readyState) {
      // if we got data we're not polling
      this.polling = false;
      this.emit('pollComplete');

      if ('open' == this.readyState) {
        this.poll();
      } else {
        _logger.fine('ignoring poll - transport state "${this.readyState}"');
      }
    }
  }

  /**
   * For polling, send a close packet.
   *
   * @api private
   */
  doClose() {
    var self = this;

    var close = ([_]) {
      _logger.fine('writing close packet');
      self.write([{ 'type': 'close' }]);
    };

    if ('open' == this.readyState) {
      _logger.fine('transport open - closing');
      close();
    } else {
      // in case we're trying to close while
      // handshaking is in progress (GH-164)
      _logger.fine('transport not open - deferring close');
      this.once('open', close);
    }
  }

  /**
   * Writes a packets payload.
   *
   * @param {Array} data packets
   * @param {Function} drain callback
   * @api private
   */
  write(List<Map> packets) {
    var self = this;
    this.writable = false;
    var callbackfn = (_) {
      self.writable = true;
      self.emit('drain');
    };

    PacketParser.encodePayload(packets, supportsBinary: this.supportsBinary, callback: (data) {
      self.doWrite(data, callbackfn);
    });
  }

  /**
   * Generates uri for connection.
   *
   * @api private
   */
  uri() {
    var query = this.query ?? {};
    var schema = this.secure ? 'https' : 'http';
    var port = '';

    // cache busting is forced
    if (this.timestampRequests != false) {
      query[this.timestampParam] = new DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    }

    if (this.supportsBinary == false && !query.containsKey('sid')) {
      query['b64'] = 1;
    }


    // avoid port if default for schema
    if (this.port != null && (('https' == schema && this.port != 443) ||
        ('http' == schema && this.port != 80))) {
      port = ':${this.port}';
    }

    var queryString = encode(query);

    // prepend ? to query
    if (queryString.isNotEmpty) {
      queryString = '?$queryString';
    }

    var ipv6 = this.hostname.contains(':');
    return schema + '://' + (ipv6 ? '[' + this.hostname + ']' : this.hostname) + port + this.path + queryString;
  }

  void doWrite(data, callback);
  void doPoll();
}
