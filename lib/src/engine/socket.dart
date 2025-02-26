// Copyright (C) 2017 Potix Corporation. All Rights Reserved
// History: 26/04/2017
// Author: jumperchen<jumperchen@potix.com>

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_client/src/engine/parseqs.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart' as parser;
import 'transport.dart';

// ignore: uri_does_not_exist
import './transport/transports_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.js_interop) './transport/transports.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) './transport/io_transports.dart';

final Logger _logger = Logger('socket_io_client:engine.Socket');

///
/// Socket constructor.
///
/// @param {String|Object} uri or options
/// @param {Object} options
/// @api public
///
class Socket extends EventEmitter {
  String? id;
  Transport? transport;
  String binaryType = 'arraybuffer';
  String readyState = '';
  List writeBuffer = [];

  int prevBufferLen = 0;
  List? upgrades;
  int? pingInterval;
  int? pingTimeout;
  Timer? pingTimeoutTimer;
  bool? upgrading;
  int? maxPayload;

  late Map opts;
  late bool secure;
  late String hostname;
  int? port;
  late List<String> transports;

  Socket(String uri, Map? opts) {
    opts = opts ?? <dynamic, dynamic>{};

    if (uri.isNotEmpty) {
      var uri0 = Uri.parse(uri);
      opts['hostname'] = uri0.host;
      opts['secure'] = uri0.scheme == 'https' || uri0.scheme == 'wss';
      opts['port'] = uri0.port;
      if (uri0.hasQuery) opts['query'] = uri0.query;
    } else if (opts.containsKey('host')) {
      opts['hostname'] = Uri.parse(opts['host']).host;
    }

    secure =
        opts['secure'] ?? false /*?? (window.location.protocol == 'https:')*/;

    if (opts['hostname'] != null && !opts.containsKey('port')) {
      // if no port is specified manually, use the protocol default
      opts['port'] = secure ? '443' : '80';
    }

    hostname =
        opts['hostname'] /*?? (window.location.hostname ?? 'localhost')*/;
    port = opts[
            'port'] /*??
        (window.location.port.isNotEmpty
            ? int.parse(window.location.port)
            : (this.secure ? 443 : 80))*/
        ;

    transports = opts['transports'] ?? ['polling', 'websocket', 'webtransport'];
    writeBuffer = [];
    prevBufferLen = 0;

    this.opts = {
      'path': "/engine.io",
      'agent': false,
      'withCredentials': false,
      'upgrade': true,
      'timestampParam': "t",
      'rememberUpgrade': false,
      'addTrailingSlash': true,
      'rejectUnauthorized': true,
      'perMessageDeflate': {
        'threshold': 1024,
      },
      'transportOptions': {},
      'closeOnBeforeunload': false,
      ...opts,
    };

    this.opts['path'] =
        this.opts['path'].toString().replaceFirst(RegExp(r'/$'), '') +
            (this.opts['addTrailingSlash'] ? '/' : '');

    if (opts['query'] is String) {
      this.opts['query'] = decode(opts['query']);
    }

    // set on handshake
    id = null;
    upgrades = null;
    pingInterval = null;
    pingTimeout = null;

    // set on heartbeat
    pingTimeoutTimer = null;

    open();
  }

  static bool priorWebsocketSuccess = false;

  ///
  /// Protocol version.
  ///
  /// @api public
  static int protocol = parser.protocol; // this is an int

  ///
  /// Creates transport of the given type.
  ///
  /// @param {String} transport name
  /// @return {Transport}
  /// @api private
  Transport createTransport(name, [options]) {
    _logger.fine('creating transport "$name"');
    var query = Map<String, dynamic>.from(this.opts['query'] ?? {});

    // append engine.io protocol identifier
    query['EIO'] = parser.protocol;

    // transport name
    query['transport'] = name;

    // session id if we already have one
    if (id != null) query['sid'] = id;

    // per-transport options
    final transportOptions = this.opts['transportOptions'][name] ?? {};

    final opts = {
      ...this.opts,
      'query': query,
      'socket': this,
      'hostname': hostname,
      'secure': secure,
      'port': port,
      ...transportOptions,
    };

    return Transports.newInstance(name, opts);
  }

  ///
  /// Initializes transport to use and starts probe.
  ///
  /// @api private
  void open() {
    dynamic transport;
    if (opts['rememberUpgrade'] != null &&
        priorWebsocketSuccess &&
        transports.contains('websocket')) {
      transport = 'websocket';
    } else if (transports.isEmpty) {
      // Emit error on next tick so it can be listened to
      Timer.run(() => emitReserved('error', 'No transports available'));
      return;
    } else {
      transport = transports[0];
    }
    readyState = 'opening';

    // Retry with the next transport if the transport is disabled (jsonp: false)
    try {
      transport = createTransport(transport);
    } catch (e) {
      _logger.fine("error while creating transport: $e");
      transports.removeAt(0);
      open();
      return;
    }

    transport.open();
    setTransport(transport);
  }

  ///
  /// Sets the current transport. Disables the existing one (if any).
  ///
  /// @api private
  void setTransport(transport) {
    _logger.fine('setting transport ${transport?.name}');

    if (this.transport != null) {
      _logger.fine('clearing existing transport ${this.transport!.name}');
      this.transport!.clearListeners();
    }

    // set up transport
    this.transport = transport;

    // set up transport listeners
    transport
      ..on('drain', (_) => onDrain())
      ..on('packet', (packet) => onPacket(packet))
      ..on('error', (e) => onError(e))
      ..on('close', (reason) => onClose('transport close', reason));
  }

  ///
  /// Probes a transport.
  ///
  /// @param {String} transport name
  /// @api private
  void probe(name) {
    _logger.fine('probing transport "$name"');
    Transport? transport = createTransport(name, {'probe': true});
    var failed = false;
    dynamic cleanup;
    priorWebsocketSuccess = false;

    onTransportOpen(_) {
      if (failed) return;

      _logger.fine('probe transport "$name" opened');
      transport!.send([
        {'type': 'ping', 'data': 'probe'}
      ]);
      transport!.once('packet', (msg) {
        if (failed) return;
        if ('pong' == msg['type'] && 'probe' == msg['data']) {
          _logger.fine('probe transport "$name" pong');
          upgrading = true;
          emitReserved('upgrading', transport);
          if (transport == null) return;
          priorWebsocketSuccess = 'websocket' == transport!.name;

          _logger.fine('pausing current transport "${transport?.name}"');
          this.transport?.pause(() {
            if (failed) return;
            if ('closed' == readyState) return;
            _logger.fine('changing transport and sending upgrade packet');

            cleanup();

            setTransport(transport);
            transport!.send([
              {'type': 'upgrade'}
            ]);
            emit('upgrade', transport);
            transport = null;
            upgrading = false;
            flush();
          });
        } else {
          _logger.fine('probe transport "$name" failed');
          emitReserved('upgradeError',
              {'error': 'probe error', 'transport': transport!.name});
        }
      });
    }

    freezeTransport() {
      if (failed) return;

      // Any callback called by transport should be ignored since now
      failed = true;

      cleanup();

      transport!.close();
      transport = null;
    }

    // Handle any error that happens while probing
    onerror(err) {
      final oldTransport = transport;
      freezeTransport();

      _logger.fine('probe transport "$name" failed because of error: $err');

      emitReserved('upgradeError',
          {'error': 'probe error: $err', 'transport': oldTransport!.name});
    }

    onTransportClose(_) => onerror('transport closed');

    // When the socket is closed while we're probing
    onclose(_) => onerror('socket closed');

    // When the socket is upgraded while we're probing
    onupgrade(to) {
      if (transport != null && to.name != transport!.name) {
        _logger.fine('"${to?.name}" works - aborting "${transport?.name}"');
        freezeTransport();
      }
    }

    // Remove all listeners on the transport and on self
    cleanup = () {
      transport!.off('open', onTransportOpen);
      transport!.off('error', onerror);
      transport!.off('close', onTransportClose);
      off('close', onclose);
      off('upgrading', onupgrade);
    };

    transport!.once('open', onTransportOpen);
    transport!.once('error', onerror);
    transport!.once('close', onTransportClose);

    once('close', onclose);
    once('upgrading', onupgrade);

    if (upgrades!.contains('webtransport') && name != 'webtransport') {
      // favor WebTransport
      Timer(Duration(milliseconds: 200), () {
        if (!failed) {
          transport!.open();
        }
      });
    } else {
      transport!.open();
    }
  }

  ///
  /// Called when connection is deemed open.
  ///
  /// @api public
  void onOpen() {
    _logger.fine('socket open');
    readyState = 'open';
    priorWebsocketSuccess = 'websocket' == transport!.name;
    emitReserved('open');
    flush();

    // we check for `readyState` in case an `open`
    // listener already closed the socket
    if ('open' == readyState &&
        opts['upgrade'] == true &&
        transport?.name == 'polling') {
      _logger.fine('starting upgrade probes');
      for (var i = 0, l = upgrades!.length; i < l; i++) {
        probe(upgrades![i]);
      }
    }
  }

  ///
  /// Handles a packet.
  ///
  /// @api private
  void onPacket(Map packet) {
    if ('opening' == readyState ||
        'open' == readyState ||
        'closing' == readyState) {
      var type = packet['type'];
      var data = packet['data'];
      _logger.fine('socket receive: type "$type", data "$data"');

      emitReserved('packet', packet);

      // Socket is live - any packet counts
      emitReserved('heartbeat');
      resetPingTimeout();

      switch (type) {
        case 'open':
          onHandshake(json.decode(data));
          break;

        case 'ping':
          sendPacket(type: 'pong');
          emitReserved('ping');
          emitReserved('pong');
          break;

        case 'error':
          onError({'error': 'server error', 'code': data});
          break;

        case 'message':
          emitReserved('data', data);
          emitReserved('message', data);
          break;
      }
    } else {
      _logger.fine('packet received with socket readyState "$readyState"');
    }
  }

  ///
  /// Called upon handshake completion.
  ///
  /// @param {Object} handshake obj
  /// @api private
  void onHandshake(Map data) {
    emitReserved('handshake', data);
    id = data['sid'];
    transport!.query!['sid'] = data['sid'];
    upgrades = filterUpgrades(data['upgrades']);
    pingInterval = data['pingInterval'];
    pingTimeout = data['pingTimeout'];
    maxPayload = data['maxPayload'];
    onOpen();
    // In case open handler closes socket
    if ('closed' == readyState) return;
    resetPingTimeout();
  }

  ///
  ///Sets and resets ping timeout timer based on server pings.
  /// @api private
  ///
  void resetPingTimeout() {
    pingTimeoutTimer?.cancel();
    pingTimeoutTimer = Timer(
        Duration(
            milliseconds: pingInterval != null && pingTimeout != null
                ? (pingInterval! + pingTimeout!)
                : 0), () {
      onClose('ping timeout');
    });
  }

  ///
  /// Called on `drain` event
  ///
  /// @api private
  void onDrain() {
    writeBuffer.removeRange(0, prevBufferLen);

    // setting prevBufferLen = 0 is very important
    // for example, when upgrading, upgrade packet is sent over,
    // and a nonzero prevBufferLen could cause problems on `drain`
    prevBufferLen = 0;

    if (writeBuffer.isEmpty) {
      emitReserved('drain');
    } else {
      flush();
    }
  }

  ///
  /// Flush write buffers.
  ///
  /// @api private
  void flush() {
    if ('closed' != readyState &&
        transport!.writable == true &&
        upgrading != true &&
        writeBuffer.isNotEmpty) {
      final packets = getWritablePackets();
      _logger.fine('flushing ${packets.length} packets in socket');
      transport!.send(packets);
      // keep track of current length of writeBuffer
      // splice writeBuffer and callbackBuffer on `drain`
      prevBufferLen = writeBuffer.length;
      emit('flush');
    }
  }

  List getWritablePackets() {
    final bool shouldCheckPayloadSize = maxPayload != null &&
        transport?.name == "polling" &&
        writeBuffer.length > 1;

    if (!shouldCheckPayloadSize) {
      return writeBuffer;
    }

    int payloadSize = 1; // first packet type
    List<Map<String, dynamic>> writablePackets = [];
    for (int i = 0; i < writeBuffer.length; i++) {
      final data = writeBuffer[i]['data'];
      if (data != null) {
        payloadSize += _byteLength(data);
      }
      if (i > 0 && payloadSize > maxPayload!) {
        _logger.fine("only send $i out of ${writeBuffer.length} packets");
        return writablePackets;
      }
      payloadSize += 2; // separator + packet type
      writablePackets.add(writeBuffer[i]);
    }
    _logger.fine("payload size is $payloadSize (max: $maxPayload)");
    return writablePackets;
  }

  int _byteLength(dynamic obj) {
    if (obj is String) {
      return _utf8Length(obj);
    }
    // Assuming obj is a ByteBuffer or similar with a length property.
    return ((obj as ByteBuffer).lengthInBytes * 1.33).ceil();
  }

  int _utf8Length(String str) {
    int length = 0;
    for (int i = 0; i < str.length; i++) {
      int c = str.codeUnitAt(i);
      if (c < 0x80) {
        length += 1;
      } else if (c < 0x800) {
        length += 2;
      } else if (c < 0xD800 || c >= 0xE000) {
        length += 3;
      } else {
        i++;
        length += 4;
      }
    }
    return length;
  }

  ///
  /// Sends a message.
  ///
  /// @param {String} message.
  /// @param {Function} callback function.
  /// @param {Object} options.
  /// @return {Socket} for chaining.
  /// @api public
  Socket write(msg, options, [EventHandler? fn]) => send(msg, options, fn);

  Socket send(msg, options, [EventHandler? fn]) {
    sendPacket(type: 'message', data: msg, options: options, callback: fn);
    return this;
  }

  ///
  /// Sends a packet.
  ///
  /// @param {String} packet type.
  /// @param {String} data.
  /// @param {Object} options.
  /// @param {Function} callback function.
  /// @api private
  void sendPacket({type, data, options, EventHandler? callback}) {
    if ('closing' == readyState || 'closed' == readyState) {
      return;
    }

    options = options ?? {};
    options['compress'] = false != options['compress'];

    var packet = {'type': type, 'data': data, 'options': options};
    emitReserved('packetCreate', packet);
    writeBuffer.add(packet);
    if (callback != null) once('flush', callback);
    flush();
  }

  ///
  /// Closes the connection.
  ///
  /// @api private
  Socket close() {
    close() {
      onClose('forced close');
      _logger.fine('socket closing - telling transport to close');
      transport!.close();
    }

    dynamic temp;
    cleanupAndClose(_) {
      off('upgrade', temp);
      off('upgradeError', temp);
      close();
    }

    // a workaround for dart to access the local variable;
    temp = cleanupAndClose;

    waitForUpgrade() {
      // wait for upgrade to finish since we can't send packets while pausing a transport
      once('upgrade', cleanupAndClose);
      once('upgradeError', cleanupAndClose);
    }

    if ('opening' == readyState || 'open' == readyState) {
      readyState = 'closing';

      if (writeBuffer.isNotEmpty) {
        once('drain', (_) {
          if (upgrading == true) {
            waitForUpgrade();
          } else {
            close();
          }
        });
      } else if (upgrading == true) {
        waitForUpgrade();
      } else {
        close();
      }
    }

    return this;
  }

  ///
  /// Called upon transport error
  ///
  /// @api private
  void onError(err) {
    _logger.fine('socket error $err');
    priorWebsocketSuccess = false;
    emitReserved('error', err);
    onClose('transport error', err);
  }

  ///
  /// Called upon transport close.
  ///
  /// @api private
  void onClose(reason, [desc]) {
    if ('opening' == readyState ||
        'open' == readyState ||
        'closing' == readyState) {
      _logger.fine('socket close with reason: "$reason"');

      // clear timers
      pingTimeoutTimer?.cancel();

      // stop event from firing again for transport
      transport!.off('close');

      // ensure transport won't stay open
      transport!.close();

      // ignore further transport communication
      transport!.clearListeners();

      // set ready state
      readyState = 'closed';

      // clear session id
      id = null;

      // emit close event
      emitReserved('close', {'reason': reason, 'desc': desc});

      // clean buffers after, so users can still
      // grab the buffers on `close` event
      writeBuffer = [];
      prevBufferLen = 0;
    }
  }

  ///
  /// Filters upgrades, returning only those matching client transports.
  ///
  /// @param {Array} server upgrades
  /// @api private
  ///
  List filterUpgrades(List upgrades) =>
      transports.where((transport) => upgrades.contains(transport)).toList();
}
