/**
 * manager.dart
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
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_common/src/parser/parser.dart';
import 'package:socket_io_client/src/on.dart';
import 'package:socket_io_client/src/socket.dart';
import 'package:socket_io_client/src/engine/socket.dart' as engine_socket;
import 'package:socket_io_client/src/on.dart' as util;

final Logger _logger = Logger('socket_io_client:Manager');

///
/// `Manager` constructor.
///
/// @param {String} engine instance or engine uri/opts
/// @param {Object} options
/// @api public
///
class Manager extends EventEmitter {
  // Namespaces
  Map<String, Socket> nsps;
  List subs;
  Map options;

  bool _reconnection;
  num _reconnectionAttempts;
  num _reconnectionDelay;
  num _randomizationFactor;
  num _reconnectionDelayMax;
  num _timeout;
  _Backoff backoff;
  String readyState;
  String uri;
  List connecting;
  num lastPing;
  bool encoding;
  List packetBuffer;
  bool reconnecting = false;

  engine_socket.Socket engine;
  Encoder encoder;
  Decoder decoder;
  bool autoConnect;
  bool skipReconnect;

  Manager({uri, Map options}) {
    options = options ?? <dynamic, dynamic>{};

    options['path'] ??= '/socket.io';
    nsps = {};
    subs = [];
    this.options = options;
    reconnection = options['reconnection'] != false;
    reconnectionAttempts =
        options['reconnectionAttempts'] ?? double.infinity;
    reconnectionDelay = options['reconnectionDelay'] ?? 1000;
    reconnectionDelayMax = options['reconnectionDelayMax'] ?? 5000;
    randomizationFactor = options['randomizationFactor'] ?? 0.5;
    backoff = _Backoff(
        min: reconnectionDelay,
        max: reconnectionDelayMax,
        jitter: randomizationFactor);
    timeout = options['timeout'] ?? 20000;
    readyState = 'closed';
    this.uri = uri;
    connecting = [];
    lastPing = null;
    encoding = false;
    packetBuffer = [];
    encoder = Encoder();
    decoder = Decoder();
    autoConnect = options['autoConnect'] != false;
    if (autoConnect) open();
  }

  ///
  /// Propagate given event to sockets and emit on `this`
  ///
  /// @api private
  ///
  void emitAll(String event, [data]) {
    emit(event, data);
    for (var nsp in nsps.keys) {
      nsps[nsp].emit(event, data);
    }
  }

  ///
  /// Update `socket.id` of all sockets
  ///
  /// @api private
  ///
  void updateSocketIds() {
    for (var nsp in nsps.keys) {
      nsps[nsp].id = generateId(nsp);
    }
  }

  ///
  /// generate `socket.id` for the given `nsp`
  ///
  /// @param {String} nsp
  /// @return {String}
  /// @api private
  ///
  String generateId(String nsp) {
    if (nsp.startsWith('/')) nsp = nsp.substring(1);
    return (nsp.isEmpty ? '' : (nsp + '#')) + engine.id;
  }

  ///
  /// Sets the `reconnection` config.
  ///
  /// @param {Boolean} true/false if it should automatically reconnect
  /// @return {Manager} self or value
  /// @api public
  ///
  bool get reconnection => _reconnection;
  set reconnection(bool v) => _reconnection = v;

  ///
  /// Sets the reconnection attempts config.
  ///
  /// @param {Number} max reconnection attempts before giving up
  /// @return {Manager} self or value
  /// @api public
  ///
  num get reconnectionAttempts => _reconnectionAttempts;
  set reconnectionAttempts(num v) => _reconnectionAttempts = v;

  ///
  /// Sets the delay between reconnections.
  ///
  /// @param {Number} delay
  /// @return {Manager} self or value
  /// @api public
  ///
  num get reconnectionDelay => _reconnectionDelay;
  set reconnectionDelay(num v) => _reconnectionDelay = v;

  num get randomizationFactor => _randomizationFactor;
  set randomizationFactor(num v) {
    _randomizationFactor = v;
    if (backoff != null) backoff.jitter = v;
  }

  ///
  /// Sets the maximum delay between reconnections.
  ///
  /// @param {Number} delay
  /// @return {Manager} self or value
  /// @api public
  ///
  num get reconnectionDelayMax => _reconnectionDelayMax;
  set reconnectionDelayMax(num v) {
    _reconnectionDelayMax = v;
    if (backoff != null) backoff.max = v;
  }

  ///
  /// Sets the connection timeout. `false` to disable
  ///
  /// @return {Manager} self or value
  /// @api public
  ///
  num get timeout => _timeout;
  set timeout(num v) => _timeout = v;

  ///
  /// Starts trying to reconnect if reconnection is enabled and we have not
  /// started reconnecting yet
  ///
  /// @api private
  ///
  void maybeReconnectOnOpen() {
    // Only try to reconnect if it's the first time we're connecting
    if (!reconnecting &&
        _reconnection &&
        backoff.attempts == 0) {
      // keeps reconnection from firing twice for the same reconnection loop
      reconnect();
    }
  }

  ///
  /// Sets the current transport `socket`.
  ///
  /// @param {Function} optional, callback
  /// @return {Manager} self
  /// @api public
  ///
  Manager open({callback, Map opts}) => connect(callback: callback, opts: opts);

  Manager connect({callback, Map opts}) {
    _logger.fine('readyState $readyState');
    if (readyState.contains('open')) return this;

    _logger.fine('opening $uri');
    engine = engine_socket.Socket(uri, options);
    var socket = engine;
    readyState = 'opening';
    skipReconnect = false;

    // emit `open`
    var openSub = util.on(socket, 'open', (_) {
      onopen();
      if (callback != null) callback();
    });

    // emit `connect_error`
    var errorSub = util.on(socket, 'error', (data) {
      _logger.fine('connect_error');
      cleanup();
      readyState = 'closed';
      emitAll('connect_error', data);
      if (callback != null) {
        callback({'error': 'Connection error', 'data': data});
      } else {
        // Only do this if there is no fn to handle the error
        maybeReconnectOnOpen();
      }
    });

    // emit `connect_timeout`
    if (_timeout != null) {
      var timeout = _timeout;
      _logger.fine('connect attempt will timeout after $timeout');

      // set timer
      var timer = Timer(Duration(milliseconds: timeout), () {
        _logger.fine('connect attempt timed out after $timeout');
        openSub.destroy();
        socket.close();
        socket.emit('error', 'timeout');
        emitAll('connect_timeout', timeout);
      });

      subs.add(Destroyable(() => timer?.cancel()));
    }

    subs.add(openSub);
    subs.add(errorSub);

    return this;
  }

  ///
  /// Called upon transport open.
  ///
  /// @api private
  ///
  void onopen([_]) {
    _logger.fine('open');

    // clear old subs
    cleanup();

    // mark as open
    readyState = 'open';
    emit('open');

    // add subs
    var socket = engine;
    subs.add(util.on(socket, 'data', ondata));
    subs.add(util.on(socket, 'ping', onping));
    subs.add(util.on(socket, 'pong', onpong));
    subs.add(util.on(socket, 'error', onerror));
    subs.add(util.on(socket, 'close', onclose));
    subs.add(util.on(decoder, 'decoded', ondecoded));
  }

  ///
  /// Called upon a ping.
  ///
  /// @api private
  ///
  void onping([_]) {
    lastPing = DateTime.now().millisecondsSinceEpoch;
    emitAll('ping');
  }

  ///
  /// Called upon a packet.
  ///
  /// @api private
  ///
  void onpong([_]) {
    emitAll('pong', DateTime.now().millisecondsSinceEpoch - lastPing);
  }

  ///
  /// Called with data.
  ///
  /// @api private
  ///
  void ondata(data) {
    decoder.add(data);
  }

  ///
  /// Called when parser fully decodes a packet.
  ///
  /// @api private
  ///
  void ondecoded(packet) {
    emit('packet', packet);
  }

  ///
  /// Called upon socket error.
  ///
  /// @api private
  ///
  void onerror(err) {
    _logger.fine('error $err');
    emitAll('error', err);
  }

  ///
  /// Creates a socket for the given `nsp`.
  ///
  /// @return {Socket}
  /// @api public
  ///
  Socket socket(String nsp, Map opts) {
    var socket = nsps[nsp];

    var onConnecting = ([_]) {
      if (!connecting.contains(socket)) {
        connecting.add(socket);
      }
    };

    if (socket == null) {
      socket = Socket(this, nsp, opts);
      nsps[nsp] = socket;
      socket.on('connecting', onConnecting);
      socket.on('connect', (_) {
        socket.id = generateId(nsp);
      });

      if (autoConnect) {
        // manually call here since connecting event is fired before listening
        onConnecting();
      }
    }

    return socket;
  }

  ///
  /// Called upon a socket close.
  ///
  /// @param {Socket} socket
  ///
  void destroy(socket) {
    connecting.remove(socket);
    if (connecting.isNotEmpty) return;

    close();
  }

  ///
  /// Writes a packet.
  ///
  /// @param {Object} packet
  /// @api private
  ///
  void packet(Map packet) {
    _logger.fine('writing packet $packet');
    if (packet.containsKey('query') && packet['type'] == 0) {
      packet['nsp'] += '''?${packet['query']}''';
    }

    if (encoding != true) {
      // encode, then write to engine with result
      encoding = true;
      encoder.encode(packet, (encodedPackets) {
        for (var i = 0; i < encodedPackets.length; i++) {
          engine.write(encodedPackets[i], packet['options']);
        }
        encoding = false;
        processPacketQueue();
      });
    } else {
      // add packet to the queue
      packetBuffer.add(packet);
    }
  }

  ///
  /// If packet buffer is non-empty, begins encoding the
  /// next packet in line.
  ///
  /// @api private
  ///
  void processPacketQueue() {
    if (packetBuffer.isNotEmpty && encoding != true) {
      var pack = packetBuffer.removeAt(0);
      packet(pack);
    }
  }

  ///
  /// Clean up transport subscriptions and packet buffer.
  ///
  /// @api private
  ///
  void cleanup() {
    _logger.fine('cleanup');

    var subsLength = subs.length;
    for (var i = 0; i < subsLength; i++) {
      var sub = subs.removeAt(0);
      sub.destroy();
    }

    packetBuffer = [];
    encoding = false;
    lastPing = null;

    decoder.destroy();
  }

  ///
  /// Close the current socket.
  ///
  /// @api private
  ///
  void close() => disconnect();

  void disconnect() {
    _logger.fine('disconnect');
    skipReconnect = true;
    reconnecting = false;
    if ('opening' == readyState) {
      // `onclose` will not fire because
      // an open event never happened
      cleanup();
    }
    backoff.reset();
    readyState = 'closed';
    engine?.close();
  }

  ///
  /// Called upon engine close.
  ///
  /// @api private
  ///
  void onclose(error) {
    _logger.fine('onclose');

    cleanup();
    backoff.reset();
    readyState = 'closed';
    emit('close', error['reason']);

    if (_reconnection && !skipReconnect) {
      reconnect();
    }
  }

  ///
  /// Attempt a reconnection.
  ///
  /// @api private
  ///
  Manager reconnect() {
    if (reconnecting || skipReconnect) return this;

    if (backoff.attempts >= _reconnectionAttempts) {
      _logger.fine('reconnect failed');
      backoff.reset();
      emitAll('reconnect_failed');
      reconnecting = false;
    } else {
      var delay = backoff.duration;
      _logger.fine('will wait %dms before reconnect attempt', delay);

      reconnecting = true;
      var timer = Timer(Duration(milliseconds: delay), () {
        if (skipReconnect) return;

        _logger.fine('attempting reconnect');
        emitAll('reconnect_attempt', backoff.attempts);
        emitAll('reconnecting', backoff.attempts);

        // check again for the case socket closed in above events
        if (skipReconnect) return;

        open(callback: ([err]) {
          if (err != null) {
            _logger.fine('reconnect attempt error');
            reconnecting = false;
            reconnect();
            emitAll('reconnect_error', err['data']);
          } else {
            _logger.fine('reconnect success');
            onreconnect();
          }
        });
      });

      subs.add(Destroyable(() => timer.cancel()));
    }
    return this;
  }

  ///
  /// Called upon successful reconnect.
  ///
  /// @api private
  ///
  void onreconnect() {
    var attempt = backoff.attempts;
    reconnecting = false;
    backoff.reset();
    updateSocketIds();
    emitAll('reconnect', attempt);
  }
}

///
/// Initialize backoff timer with `opts`.
///
/// - `min` initial timeout in milliseconds [100]
/// - `max` max timeout [10000]
/// - `jitter` [0]
/// - `factor` [2]
///
/// @param {Object} opts
/// @api public
class _Backoff {
  num _ms;
  num _max;
  num _factor;
  num _jitter;
  num attempts;

  _Backoff({min = 100, max = 10000, jitter = 0, factor = 2})
      : _ms = min,
        _max = max,
        _factor = factor {
    _jitter = jitter > 0 && jitter <= 1 ? jitter : 0;
    attempts = 0;
  }

  ///
  /// Return the backoff duration.
  ///
  /// @return {Number}
  /// @api public
  ///
  num get duration {
    var ms = _ms * math.pow(_factor, attempts++);
    if (_jitter > 0) {
      var rand = math.Random().nextDouble();
      var deviation = (rand * _jitter * ms).floor();
      ms = ((rand * 10).floor() & 1) == 0 ? ms - deviation : ms + deviation;
    }
    // #39: avoid an overflow with negative value
    ms = math.min(ms, _max);
    return ms <= 0 ? _max : ms;
  }

  ///
  /// Reset the number of attempts.
  ///
  /// @api public
  ///
  void reset() {
    attempts = 0;
  }

  ///
  /// Set the minimum duration
  ///
  /// @api public
  ///
  set min(min) => _ms = min;

  ///
  /// Set the maximum duration
  ///
  /// @api public
  ///
  set max(max) => _max = max;

  ///
  /// Set the jitter
  ///
  /// @api public
  ///
  set jitter(jitter) => _jitter = jitter;
}
