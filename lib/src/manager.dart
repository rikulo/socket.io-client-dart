// Copyright (C) 2017 Potix Corporation. All Rights Reserved
// History: 2017-04-26 15:27
// Author: jumperchen<jumperchen@potix.com>
import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_common/src/parser/parser.dart';
import 'package:socket_io_client/src/on.dart';
import 'package:socket_io_client/src/socket.dart';
import 'package:socket_io_client/src/engine/socket.dart' as engine_socket;
import 'package:socket_io_client/src/on.dart' as util;
import 'package:socket_io_client/src/engine/transport/http_client_adapter.dart';
import 'package:socket_io_client/src/engine/transport/http_client_adapter_factory.dart'
    show createPlatformHttpClientAdapter;

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
  Map<String, Socket> nsps = {};
  List subs = [];
  late Map? options;
  final HttpClientAdapter _httpClientAdapter;

  ///
  /// Sets the `reconnection` config.
  ///
  /// @param {Boolean} true/false if it should automatically reconnect
  /// @return {Manager} self or value
  /// @api public
  ///
  bool? reconnection;

  ///
  /// Sets the reconnection attempts config.
  ///
  /// @param {Number} max reconnection attempts before giving up
  /// @return {Manager} self or value
  /// @api public
  ///
  num? reconnectionAttempts;

  ///
  /// Sets the delay between reconnections.
  ///
  /// @param {Number} delay
  /// @return {Manager} self or value
  /// @api public
  ///
  num? _reconnectionDelay;
  num? _randomizationFactor;
  num? _reconnectionDelayMax;

  ///
  /// Sets the connection timeout. `false` to disable
  ///
  /// @return {Manager} self or value
  /// @api public
  ///
  num? timeout;
  _Backoff? _backoff;
  String readyState = 'closed';
  late String uri;
  bool reconnecting = false;

  engine_socket.Socket? engine;
  late Encoder encoder;
  late Decoder decoder;
  late bool autoConnect;
  bool? skipReconnect;

  Manager({uri, Map? options})
      : _httpClientAdapter = createPlatformHttpClientAdapter(),
        super() {
    options = options ?? <dynamic, dynamic>{};
    options['transportOptions'] = {
      'websocket': {
        'httpClientAdapter': options['httpClientAdapter'] ?? _httpClientAdapter
      },
      ...?options['transportOptions'],
    };

    options['path'] ??= '/socket.io';
    // ignore: prefer_initializing_formals
    this.options = options;
    reconnection = options['reconnection'] != false;
    reconnectionAttempts = options['reconnectionAttempts'] ?? double.infinity;
    reconnectionDelay = options['reconnectionDelay'] ?? 1000;
    reconnectionDelayMax = options['reconnectionDelayMax'] ?? 5000;
    randomizationFactor = options['randomizationFactor'] ?? 0.5;
    _backoff = _Backoff(
        min: reconnectionDelay,
        max: reconnectionDelayMax,
        jitter: randomizationFactor);
    timeout = options['timeout'] ?? 20000;
    readyState = 'closed';

    // ignore: prefer_initializing_formals
    this.uri = uri;

    if (options['parser'] != null) {
      encoder = options['parser'].encoder();
      decoder = options['parser'].decoder();
    } else {
      encoder = Encoder();
      decoder = Decoder();
    }

    autoConnect = options['autoConnect'] != false;
    if (autoConnect) open();
  }

  num? get reconnectionDelay => _reconnectionDelay;
  set reconnectionDelay(num? v) {
    _reconnectionDelay = v;
    _backoff?.min = v;
  }

  num? get randomizationFactor => _randomizationFactor;
  set randomizationFactor(num? v) {
    _randomizationFactor = v;
    _backoff?.jitter = v;
  }

  ///
  /// Sets the maximum delay between reconnections.
  ///
  /// @param {Number} delay
  /// @return {Manager} self or value
  /// @api public
  ///
  num? get reconnectionDelayMax => _reconnectionDelayMax;
  set reconnectionDelayMax(num? v) {
    _reconnectionDelayMax = v;
    _backoff?.max = v;
  }

  ///
  /// Starts trying to reconnect if reconnection is enabled and we have not
  /// started reconnecting yet
  ///
  /// @api private
  ///
  void maybeReconnectOnOpen() {
    // Only try to reconnect if it's the first time we're connecting
    if (!reconnecting && reconnection == true && _backoff!.attempts == 0) {
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
  Manager open({callback, Map? opts}) {
    _logger.fine('readyState $readyState');
    if (readyState.contains('open')) return this;

    _logger.fine('opening $uri');
    engine = engine_socket.Socket(uri, options);
    var socket = engine!;
    readyState = 'opening';
    skipReconnect = false;

    // emit `open`
    var openSubDestroy = util.on(socket, 'open', (_) {
      onopen();
      if (callback != null) callback();
    });

    Function(dynamic error) onError;
    // emit `connect_error`
    var errorSub = util.on(
        socket,
        'error',
        onError = (error) {
          _logger.fine('error');
          cleanup();
          readyState = 'closed';
          emitReserved('error', error);
          if (callback != null) {
            callback({'error': 'Connection error', 'data': error});
          } else {
            // Only do this if there is no fn to handle the error
            maybeReconnectOnOpen();
          }
        });

    // emit `connect_timeout`
    if (timeout != null) {
      _logger.fine('connect attempt will timeout after $timeout');

      if (timeout == 0) {
        openSubDestroy
            .destroy(); // prevents a race condition with the 'open' event
      }
      // set timer
      var timer = Timer(Duration(milliseconds: timeout!.toInt()), () {
        _logger.fine('connect attempt timed out after $timeout');
        openSubDestroy.destroy();
        onError('timeout');
        socket.close();
      });

      subs.add(Destroyable(() => timer.cancel()));
    }

    subs.add(openSubDestroy);
    subs.add(errorSub);

    return this;
  }

  /// Alias for open()
  ///
  /// @return self
  /// @public
  Manager connect({callback, Map? opts}) =>
      open(callback: callback, opts: opts);

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
    emitReserved('open');

    // add subs
    var socket = engine!;
    subs.add(util.on(socket, 'ping', onping));
    subs.add(util.on(socket, 'data', ondata));
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
    emitReserved('ping');
  }

  ///
  /// Called with data.
  ///
  /// @api private
  ///
  void ondata(data) {
    try {
      decoder.add(data);
    } catch (e) {
      onclose('parse error');
    }
  }

  ///
  /// Called when parser fully decodes a packet.
  ///
  /// @api private
  ///
  void ondecoded(packet) {
    // the nextTick call prevents an exception in a user-provided event listener from triggering a disconnection due to a "parse error"
    Future.microtask(() {
      emitReserved('packet', packet);
    });
  }

  ///
  /// Called upon socket error.
  ///
  /// @api private
  ///
  void onerror(err) {
    _logger.fine('error $err');
    emitReserved('error', err);
  }

  ///
  /// Creates a socket for the given `nsp`.
  ///
  /// @return {Socket}
  /// @api public
  ///
  Socket socket(String nsp, Map opts) {
    var socket = nsps[nsp];

    if (socket == null) {
      socket = Socket(this, nsp, opts);
      nsps[nsp] = socket;
    } else if (autoConnect && !socket.active) {
      socket.connect();
    }

    return socket;
  }

  ///
  /// Called upon a socket close.
  ///
  /// @param {Socket} socket
  ///
  void destroy(socket) {
    final nsps = this.nsps.keys;

    for (var nsp in nsps) {
      final socket = this.nsps[nsp];

      if (socket!.active) {
        _logger.fine('socket $nsp is still active, skipping close');
        return;
      }
    }

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

    var encodedPackets = encoder.encode(packet);

    for (var i = 0; i < encodedPackets.length; i++) {
      engine!.write(encodedPackets[i], packet['options']);
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
    onclose('forced close');
    engine?.close();
  }

  ///
  /// Called upon engine close.
  ///
  /// @api private
  ///
  void onclose(error) {
    _logger.fine("closed due to ${error is Map ? error['reason'] : error}");

    cleanup();
    _backoff!.reset();
    readyState = 'closed';
    emitReserved('close', error is Map ? error['reason'] : error);

    if (reconnection == true && !skipReconnect!) {
      reconnect();
    }
  }

  ///
  /// Attempt a reconnection.
  ///
  /// @api private
  ///
  Manager reconnect() {
    if (reconnecting || skipReconnect!) return this;

    if (_backoff!.attempts >= reconnectionAttempts!) {
      _logger.fine('reconnect failed');
      _backoff!.reset();
      emitReserved('reconnect_failed');
      reconnecting = false;
    } else {
      var delay = _backoff!.duration;
      _logger.fine('will wait %dms before reconnect attempt', delay);

      reconnecting = true;
      var timer = Timer(Duration(milliseconds: delay.toInt()), () {
        if (skipReconnect!) return;

        _logger.fine('attempting reconnect');
        emit('reconnect_attempt', _backoff!.attempts);

        // check again for the case socket closed in above events
        if (skipReconnect!) return;

        open(callback: ([err]) {
          if (err != null) {
            _logger.fine('reconnect attempt error');
            reconnecting = false;
            reconnect();
            emitReserved('reconnect_error', err['data']);
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
    var attempt = _backoff!.attempts;
    reconnecting = false;
    _backoff!.reset();
    emit('reconnect', attempt);
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
  final num _factor;
  late num _jitter;
  num attempts = 0;

  _Backoff({min = 100, max = 10000, jitter = 0, factor = 2})
      : _ms = min,
        _max = max,
        _factor = factor {
    _jitter = jitter > 0 && jitter <= 1 ? jitter : 0;
  }

  ///
  /// Return the backoff duration.
  ///
  /// @return {Number}
  /// @api public
  ///
  num get duration {
    var ms = math.min(_ms * math.pow(_factor, attempts++), 1e100);
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
