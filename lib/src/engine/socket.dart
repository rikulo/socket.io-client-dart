import 'dart:async';
import 'dart:convert';
/**
 * socket.dart
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
//import 'dart:html';

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_client/src/engine/parseqs.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart' as parser;
import 'package:socket_io_client/src/engine/transport/polling_transport.dart';
import './transport/transport.dart';

// ignore: uri_does_not_exist
import './transport/transports_stub.dart'
// ignore: uri_does_not_exist
if (dart.library.html) './transport/transports.dart'
// ignore: uri_does_not_exist
if (dart.library.io) './transport/io_transports.dart';

final Logger _logger = new Logger('socket_io_client:engine.Socket');

/**
 * Socket constructor.
 *
 * @param {String|Object} uri or options
 * @param {Object} options
 * @api public
 */
class Socket extends EventEmitter {
  Map opts;
  Uri uri;
  bool secure;
  bool agent;
  String hostname;
  int port;
  Map query;
  bool upgrade;
  String path;
  bool forceJSONP;
  bool jsonp;
  bool forceBase64;
  bool enablesXDR;
  String timestampParam;
  var timestampRequests;
  List<String> transports;
  Map transportOptions;
  String readyState;
  List writeBuffer;
  int prevBufferLen;
  int policyPort;
  bool rememberUpgrade;
  var binaryType;
  bool onlyBinaryUpgrades;
  Map perMessageDeflate;
  String id;
  List upgrades;
  int pingInterval;
  int pingTimeout;
  Timer pingIntervalTimer;
  Timer pingTimeoutTimer;
  int requestTimeout;
  Transport transport;
  bool supportsBinary;
  bool upgrading;
  Map extraHeaders;

  Socket(String uri, Map opts) {
    opts = opts ?? <dynamic, dynamic>{};

    if (uri.isNotEmpty) {
      this.uri = Uri.parse(uri);
      opts['hostname'] = this.uri.host;
      opts['secure'] = this.uri.scheme == 'https' || this.uri.scheme == 'wss';
      opts['port'] = this.uri.port;
      if (this.uri.hasQuery) opts['query'] = this.uri.query;
    } else if (opts.containsKey('host')) {
      opts['hostname'] = Uri.parse(opts['host']).host;
    }

    this.secure = opts['secure'] /*?? (window.location.protocol == 'https:')*/;

    if (opts['hostname'] != null && !opts.containsKey('port')) {
      // if no port is specified manually, use the protocol default
      opts['port'] = this.secure ? '443' : '80';
    }

    this.agent = opts['agent'] ?? false;
    this.hostname =
        opts['hostname'] /*?? (window.location.hostname ?? 'localhost')*/;
    this.port = opts['port'] /*??
        (window.location.port.isNotEmpty
            ? int.parse(window.location.port)
            : (this.secure ? 443 : 80))*/;
    var query = opts['query'] ?? {};
    if (query is String)
      this.query = decode(query);
    else if (query is Map) {
      this.query = query;
    }

    this.upgrade = opts['upgrade'] != false;
    this.path = (opts['path'] ?? '/engine.io')
            .toString()
            .replaceFirst(new RegExp(r'\/$'), '') +
        '/';
    this.forceJSONP = opts['forceJSONP'] == true;
    this.jsonp = opts['jsonp'] != false;
    this.forceBase64 = opts['forceBase64'] == true;
    this.enablesXDR = opts['enablesXDR'] == true;
    this.timestampParam = opts['timestampParam'] ?? 't';
    this.timestampRequests = opts['timestampRequests'];
    this.transports = opts['transports'] ?? ['polling', 'websocket'];
    this.transportOptions = opts['transportOptions'] ?? {};
    this.readyState = '';
    this.writeBuffer = [];
    this.prevBufferLen = 0;
    this.policyPort = opts['policyPort'] ?? 843;
    this.rememberUpgrade = opts['rememberUpgrade'] ?? false;
    this.binaryType = null;
    this.onlyBinaryUpgrades = opts['onlyBinaryUpgrades'];

    if (!opts.containsKey('perMessageDeflate') ||
        opts['perMessageDeflate'] == true) {
      this.perMessageDeflate =
          opts['perMessageDeflate'] is Map ? opts['perMessageDeflate'] : {};
      if (!this.perMessageDeflate.containsKey('threshold'))
        this.perMessageDeflate['threshold'] = 1024;
    }

    this.extraHeaders = opts['extraHeaders'] ?? {};
    // SSL options for Node.js client
//  this.pfx = opts.pfx || null;
//  this.key = opts.key || null;
//  this.passphrase = opts.passphrase || null;
//  this.cert = opts.cert || null;
//  this.ca = opts.ca || null;
//  this.ciphers = opts.ciphers || null;
//  this.rejectUnauthorized = opts.rejectUnauthorized === undefined ? true : opts.rejectUnauthorized;
//  this.forceNode = !!opts.forceNode;

    // other options for Node.js client
//  var freeGlobal = typeof global === 'object' && global;
//  if (freeGlobal.global === freeGlobal) {
//  if (opts.extraHeaders && Object.keys(opts.extraHeaders).length > 0) {
//  this.extraHeaders = opts.extraHeaders;
//  }
//
//  if (opts.localAddress) {
//  this.localAddress = opts.localAddress;
//  }
//  }

    // set on handshake
//  this.id = null;
//  this.upgrades = null;
//  this.pingInterval = null;
//  this.pingTimeout = null;

    // set on heartbeat
//  this.pingIntervalTimer = null;
//  this.pingTimeoutTimer = null;

    this.open();
  }

  static bool priorWebsocketSuccess = false;

  /**
   * Protocol version.
   *
   * @api public
   */
  static int protocol = parser.protocol; // this is an int

//  /**
//   * Expose deps for legacy compatibility
//   * and standalone browser access.
//   */
//
//  Socket.Socket = Socket;
//  Socket.Transport = require('./transport');
//  Socket.transports = require('./transports/index');
//  Socket.parser = require('engine.io-parser');

  /**
   * Creates transport of the given type.
   *
   * @param {String} transport name
   * @return {Transport}
   * @api private
   */
  createTransport(name, [options]) {
    _logger.fine('creating transport "$name"');
    var query = new Map.from(this.query);

    // append engine.io protocol identifier
    query['EIO'] = parser.protocol;

    // transport name
    query['transport'] = name;

    // per-transport options
    var options = this.transportOptions[name] ?? {};

    // session id if we already have one
    if (this.id != null) query['sid'] = this.id;

    var transport = Transports.newInstance(name, {
      'query': query,
      'socket': this,
      'agent': options['agent'] ?? this.agent,
      'hostname': options['hostname'] ?? this.hostname,
      'port': options['port'] ?? this.port,
      'secure': options['secure'] ?? this.secure,
      'path': options['path'] ?? this.path,
      'forceJSONP': options['forceJSONP'] ?? this.forceJSONP,
      'jsonp': options['jsonp'] ?? this.jsonp,
      'forceBase64': options['forceBase64'] ?? this.forceBase64,
      'enablesXDR': options['enablesXDR'] ?? this.enablesXDR,
      'timestampRequests':
          options['timestampRequests'] ?? this.timestampRequests,
      'timestampParam': options['timestampParam'] ?? this.timestampParam,
      'policyPort': options['policyPort'] ?? this.policyPort,
//  'pfx: options.pfx || this.pfx,
//  'key: options.key || this.key,
//  'passphrase: options.passphrase || this.passphrase,
//  'cert: options.cert || this.cert,
//  'ca: options.ca || this.ca,
//  'ciphers: options.ciphers || this.ciphers,
//  'rejectUnauthorized: options.rejectUnauthorized || this.rejectUnauthorized,
      'perMessageDeflate':
          options['perMessageDeflate'] ?? this.perMessageDeflate,
      'extraHeaders': options['extraHeaders'] ?? this.extraHeaders,
//  'forceNode: options.forceNode || this.forceNode,
//  'localAddress: options.localAddress || this.localAddress,
      'requestTimeout': options['requestTimeout'] ?? this.requestTimeout,
      'protocols': options['protocols']
    });

    return transport;
  }

  /**
   * Initializes transport to use and starts probe.
   *
   * @api private
   */
  open() {
    var transport;
    if (this.rememberUpgrade != null &&
        priorWebsocketSuccess &&
        this.transports.contains('websocket')) {
      transport = 'websocket';
    } else if (0 == this.transports.length) {
      // Emit error on next tick so it can be listened to
      Timer.run(() => emit('error', 'No transports available'));
      return;
    } else {
      transport = this.transports[0];
    }
    this.readyState = 'opening';

    // Retry with the next transport if the transport is disabled (jsonp: false)
    try {
      transport = this.createTransport(transport);
    } catch (e) {
      this.transports.removeAt(0);
      this.open();
      return;
    }

    transport.open();
    this.setTransport(transport);
  }

  /**
   * Sets the current transport. Disables the existing one (if any).
   *
   * @api private
   */
  setTransport(transport) {
    _logger.fine('setting transport ${transport?.name}');

    if (this.transport != null) {
      _logger.fine('clearing existing transport ${this.transport?.name}');
      this.transport.clearListeners();
    }

    // set up transport
    this.transport = transport;

    // set up transport listeners
    transport
      ..on('drain', (_) => onDrain())
      ..on('packet', (packet) => onPacket(packet))
      ..on('error', (e) => onError(e))
      ..on('close', (_) => onClose('transport close'));
  }

  /**
   * Probes a transport.
   *
   * @param {String} transport name
   * @api private
   */
  probe(name) {
    _logger.fine('probing transport "$name"');
    var transport = this.createTransport(name, {'probe': true});
    var failed = false;
    var cleanup;
    priorWebsocketSuccess = false;

    var onTransportOpen = (_) {
      if (onlyBinaryUpgrades == true) {
        var upgradeLosesBinary =
            this.supportsBinary == false && transport.supportsBinary;
        failed = failed || upgradeLosesBinary;
      }
      if (failed) return;

      _logger.fine('probe transport "$name" opened');
      transport.send([
        {'type': 'ping', 'data': 'probe'}
      ]);
      transport.once('packet', (msg) {
        if (failed) return;
        if ('pong' == msg['type'] && 'probe' == msg['data']) {
          _logger.fine('probe transport "$name" pong');
          upgrading = true;
          emit('upgrading', transport);
          if (transport == null) return;
          priorWebsocketSuccess = 'websocket' == transport.name;

          _logger.fine('pausing current transport "${transport?.name}"');
          if (this.transport is PollingTransport) {
            (this.transport as PollingTransport).pause(() {
              if (failed) return;
              if ('closed' == readyState) return;
              _logger.fine('changing transport and sending upgrade packet');

              cleanup();

              setTransport(transport);
              transport.send([
                {'type': 'upgrade'}
              ]);
              emit('upgrade', transport);
              transport = null;
              upgrading = false;
              flush();
            });
          }
        } else {
          _logger.fine('probe transport "$name" failed');
          emit('upgradeError',
              {'error': 'probe error', 'transport': transport.name});
        }
      });
    };

    var freezeTransport = () {
      if (failed) return;

      // Any callback called by transport should be ignored since now
      failed = true;

      cleanup();

      transport.close();
      transport = null;
    };

    // Handle any error that happens while probing
    var onerror = (err) {
      final oldTransport = transport;
      freezeTransport();

      _logger.fine('probe transport "$name" failed because of error: $err');

      emit('upgradeError',
          {'error': 'probe error: $err', 'transport': oldTransport.name});
    };

    var onTransportClose = (_) => onerror('transport closed');

    // When the socket is closed while we're probing
    var onclose = (_) => onerror('socket closed');

    // When the socket is upgraded while we're probing
    var onupgrade = (to) {
      if (transport != null && to.name != transport.name) {
        _logger.fine('"${to?.name}" works - aborting "${transport?.name}"');
        freezeTransport();
      }
    };

    // Remove all listeners on the transport and on self
    cleanup = () {
      transport.off('open', onTransportOpen);
      transport.off('error', onerror);
      transport.off('close', onTransportClose);
      off('close', onclose);
      off('upgrading', onupgrade);
    };

    transport.once('open', onTransportOpen);
    transport.once('error', onerror);
    transport.once('close', onTransportClose);

    this.once('close', onclose);
    this.once('upgrading', onupgrade);

    transport.open();
  }

  /**
   * Called when connection is deemed open.
   *
   * @api public
   */
  onOpen() {
    _logger.fine('socket open');
    this.readyState = 'open';
    priorWebsocketSuccess = 'websocket' == this.transport.name;
    this.emit('open');
    this.flush();

    // we check for `readyState` in case an `open`
    // listener already closed the socket
    if ('open' == this.readyState &&
        this.upgrade == true &&
        this.transport is PollingTransport) {
      _logger.fine('starting upgrade probes');
      for (var i = 0, l = this.upgrades.length; i < l; i++) {
        this.probe(this.upgrades[i]);
      }
    }
  }

  /**
   * Handles a packet.
   *
   * @api private
   */
  onPacket(Map packet) {
    if ('opening' == this.readyState ||
        'open' == this.readyState ||
        'closing' == this.readyState) {
      var type = packet['type'];
      var data = packet['data'];
      _logger.fine('socket receive: type "$type", data "$data"');

      this.emit('packet', packet);

      // Socket is live - any packet counts
      this.emit('heartbeat');

      switch (type) {
        case 'open':
          this.onHandshake(json.decode(data ?? 'null'));
          break;

        case 'pong':
          this.setPing();
          this.emit('pong');
          break;

        case 'error':
          this.onError({'error': 'server error', 'code': data});
          break;

        case 'message':
          this.emit('data', data);
          this.emit('message', data);
          break;
      }
    } else {
      _logger
          .fine('packet received with socket readyState "${this.readyState}"');
    }
  }

  /**
   * Called upon handshake completion.
   *
   * @param {Object} handshake obj
   * @api private
   */
  onHandshake(Map data) {
    this.emit('handshake', data);
    this.id = data['sid'];
    this.transport.query['sid'] = data['sid'];
    this.upgrades = this.filterUpgrades(data['upgrades']);
    this.pingInterval = data['pingInterval'];
    this.pingTimeout = data['pingTimeout'];
    this.onOpen();
    // In case open handler closes socket
    if ('closed' == this.readyState) return;
    this.setPing();

    // Prolong liveness of socket on heartbeat
    this.off('heartbeat', this.onHeartbeat);
    this.on('heartbeat', this.onHeartbeat);
  }

  /**
   * Resets ping timeout.
   *
   * @api private
   */
  onHeartbeat(timeout) {
    this.pingTimeoutTimer?.cancel();
    this.pingTimeoutTimer = new Timer(
        new Duration(milliseconds: timeout ?? (pingInterval + pingTimeout)),
        () {
      if ('closed' == readyState) return;
      onClose('ping timeout');
    });
  }

  /**
   * Pings server every `this.pingInterval` and expects response
   * within `this.pingTimeout` or closes connection.
   *
   * @api private
   */
  setPing() {
    pingIntervalTimer?.cancel();
    pingIntervalTimer = new Timer(new Duration(milliseconds: pingInterval), () {
      _logger
          .fine('writing ping packet - expecting pong within ${pingTimeout}ms');
      ping();
      onHeartbeat(pingTimeout);
    });
  }

  /**
   * Sends a ping packet.
   *
   * @api private
   */
  ping() {
    this.sendPacket(type: 'ping', callback: (_) => emit('ping'));
  }

  /**
   * Called on `drain` event
   *
   * @api private
   */
  onDrain() {
    this.writeBuffer.removeRange(0, this.prevBufferLen);

    // setting prevBufferLen = 0 is very important
    // for example, when upgrading, upgrade packet is sent over,
    // and a nonzero prevBufferLen could cause problems on `drain`
    this.prevBufferLen = 0;

    if (0 == this.writeBuffer.length) {
      this.emit('drain');
    } else {
      this.flush();
    }
  }

  /**
   * Flush write buffers.
   *
   * @api private
   */
  flush() {
    if ('closed' != this.readyState &&
        this.transport.writable == true &&
        this.upgrading != true &&
        this.writeBuffer.isNotEmpty) {
      _logger.fine('flushing ${this.writeBuffer.length} packets in socket');
      this.transport.send(this.writeBuffer);
      // keep track of current length of writeBuffer
      // splice writeBuffer and callbackBuffer on `drain`
      this.prevBufferLen = this.writeBuffer.length;
      this.emit('flush');
    }
  }

  /**
   * Sends a message.
   *
   * @param {String} message.
   * @param {Function} callback function.
   * @param {Object} options.
   * @return {Socket} for chaining.
   * @api public
   */
  write(msg, options, [EventHandler fn]) => send(msg, options, fn);

  send(msg, options, [EventHandler fn]) {
    this.sendPacket(type: 'message', data: msg, options: options, callback: fn);
  }

  /**
   * Sends a packet.
   *
   * @param {String} packet type.
   * @param {String} data.
   * @param {Object} options.
   * @param {Function} callback function.
   * @api private
   */
  sendPacket({type, data, options, EventHandler callback}) {
    if ('closing' == this.readyState || 'closed' == this.readyState) {
      return;
    }

    options = options ?? {};
    options['compress'] = false != options['compress'];

    var packet = {'type': type, 'data': data, 'options': options};
    this.emit('packetCreate', packet);
    this.writeBuffer.add(packet);
    if (callback != null) this.once('flush', callback);
    this.flush();
  }

  /**
   * Closes the connection.
   *
   * @api private
   */
  close() {
    var close = () {
      onClose('forced close');
      _logger.fine('socket closing - telling transport to close');
      transport.close();
    };

    var temp;
    var cleanupAndClose = (_) {
      off('upgrade', temp);
      off('upgradeError', temp);
      close();
    };

    // a workaround for dart to access the local variable;
    temp = cleanupAndClose;

    var waitForUpgrade = () {
      // wait for upgrade to finish since we can't send packets while pausing a transport
      once('upgrade', cleanupAndClose);
      once('upgradeError', cleanupAndClose);
    };

    if ('opening' == this.readyState || 'open' == this.readyState) {
      this.readyState = 'closing';

      if (this.writeBuffer.isNotEmpty) {
        this.once('drain', (_) {
          if (this.upgrading == true) {
            waitForUpgrade();
          } else {
            close();
          }
        });
      } else if (this.upgrading == true) {
        waitForUpgrade();
      } else {
        close();
      }
    }

    return this;
  }

  /**
   * Called upon transport error
   *
   * @api private
   */
  onError(err) {
    _logger.fine('socket error $err');
    priorWebsocketSuccess = false;
    this.emit('error', err);
    this.onClose('transport error', err);
  }

  /**
   * Called upon transport close.
   *
   * @api private
   */
  onClose(reason, [desc]) {
    if ('opening' == this.readyState ||
        'open' == this.readyState ||
        'closing' == this.readyState) {
      _logger.fine('socket close with reason: "$reason"');

      // clear timers
      this.pingIntervalTimer?.cancel();
      this.pingTimeoutTimer?.cancel();

      // stop event from firing again for transport
      this.transport.off('close');

      // ensure transport won't stay open
      this.transport.close();

      // ignore further transport communication
      this.transport.clearListeners();

      // set ready state
      this.readyState = 'closed';

      // clear session id
      this.id = null;

      // emit close event
      this.emit('close', {'reason': reason, 'desc': desc});

      // clean buffers after, so users can still
      // grab the buffers on `close` event
      writeBuffer = [];
      prevBufferLen = 0;
    }
  }

  /**
   * Filters upgrades, returning only those matching client transports.
   *
   * @param {Array} server upgrades
   * @api private
   *
   */
  filterUpgrades(List upgrades) =>
      transports.where((_) => upgrades.contains(_)).toList();
}
