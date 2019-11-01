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
import 'dart:math' as Math;

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_common/src/parser/parser.dart';
import 'package:socket_io_client/src/on.dart';
import 'package:socket_io_client/src/socket.dart';
import 'package:socket_io_client/src/engine/socket.dart' as Engine;
import 'package:socket_io_client/src/on.dart' as ON;

final Logger _logger = new Logger('socket_io_client:Manager');

/**
 * `Manager` constructor.
 *
 * @param {String} engine instance or engine uri/opts
 * @param {Object} options
 * @api public
 */
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

  Engine.Socket engine;
  Encoder encoder;
  Decoder decoder;
  bool autoConnect;
  bool skipReconnect;

  Manager({uri, Map options}) {
    options = options ?? <dynamic, dynamic>{};

    options['path'] ??= '/socket.io';
    this.nsps = {};
    this.subs = [];
    this.options = options;
    this.reconnection = options['reconnection'] != false;
    this.reconnectionAttempts =
        options['reconnectionAttempts'] ?? double.infinity;
    this.reconnectionDelay = options['reconnectionDelay'] ?? 1000;
    this.reconnectionDelayMax = options['reconnectionDelayMax'] ?? 5000;
    this.randomizationFactor = options['randomizationFactor'] ?? 0.5;
    this.backoff = new _Backoff(
        min: this.reconnectionDelay,
        max: this.reconnectionDelayMax,
        jitter: this.randomizationFactor);
    this.timeout = options['timeout'] ?? 20000;
    this.readyState = 'closed';
    this.uri = uri;
    this.connecting = [];
    this.lastPing = null;
    this.encoding = false;
    this.packetBuffer = [];
    this.encoder = new Encoder();
    this.decoder = new Decoder();
    this.autoConnect = options['autoConnect'] != false;
    if (this.autoConnect) this.open();
  }

  /**
   * Propagate given event to sockets and emit on `this`
   *
   * @api private
   */
  void emitAll(String event, [data]) {
    this.emit(event, data);
    for (var nsp in this.nsps.keys) {
      this.nsps[nsp].emit(event, data);
    }
  }

  /**
   * Update `socket.id` of all sockets
   *
   * @api private
   */
  void updateSocketIds() {
    for (var nsp in this.nsps.keys) {
      this.nsps[nsp].id = this.generateId(nsp);
    }
  }

  /**
   * generate `socket.id` for the given `nsp`
   *
   * @param {String} nsp
   * @return {String}
   * @api private
   */
  String generateId(String nsp) {
    if (nsp.startsWith('/')) nsp = nsp.substring(1);
    return (nsp.isEmpty ? '' : (nsp + '#')) + this.engine.id;
  }

  /**
   * Sets the `reconnection` config.
   *
   * @param {Boolean} true/false if it should automatically reconnect
   * @return {Manager} self or value
   * @api public
   */
  bool get reconnection => this._reconnection;
  set reconnection(bool v) => this._reconnection = v;

  /**
   * Sets the reconnection attempts config.
   *
   * @param {Number} max reconnection attempts before giving up
   * @return {Manager} self or value
   * @api public
   */
  num get reconnectionAttempts => this._reconnectionAttempts;
  set reconnectionAttempts(num v) => this._reconnectionAttempts = v;

  /**
   * Sets the delay between reconnections.
   *
   * @param {Number} delay
   * @return {Manager} self or value
   * @api public
   */
  num get reconnectionDelay => this._reconnectionDelay;
  set reconnectionDelay(num v) => this._reconnectionDelay = v;

  num get randomizationFactor => this._randomizationFactor;
  set randomizationFactor(num v) {
    this._randomizationFactor = v;
    if (this.backoff != null) this.backoff.jitter = v;
  }

  /**
     * Sets the maximum delay between reconnections.
     *
     * @param {Number} delay
     * @return {Manager} self or value
     * @api public
     */
  num get reconnectionDelayMax => this._reconnectionDelayMax;
  set reconnectionDelayMax(num v) {
    this._reconnectionDelayMax = v;
    if (this.backoff != null) this.backoff.max = v;
  }

  /**
     * Sets the connection timeout. `false` to disable
     *
     * @return {Manager} self or value
     * @api public
     */
  num get timeout => this._timeout;
  set timeout(num v) => this._timeout = v;

  /**
     * Starts trying to reconnect if reconnection is enabled and we have not
     * started reconnecting yet
     *
     * @api private
     */
  maybeReconnectOnOpen() {
    // Only try to reconnect if it's the first time we're connecting
    if (!this.reconnecting &&
        this._reconnection &&
        this.backoff.attempts == 0) {
      // keeps reconnection from firing twice for the same reconnection loop
      this.reconnect();
    }
  }

  /**
     * Sets the current transport `socket`.
     *
     * @param {Function} optional, callback
     * @return {Manager} self
     * @api public
     */
  open({callback, Map opts}) => connect(callback: callback, opts: opts);

  connect({callback, Map opts}) {
    _logger.fine('readyState $readyState');
    if (this.readyState.contains('open')) return this;

    _logger.fine('opening $uri');
    this.engine = new Engine.Socket(this.uri, this.options);
    var socket = this.engine;
    this.readyState = 'opening';
    this.skipReconnect = false;

    // emit `open`
    var openSub = ON.on(socket, 'open', (_) {
      onopen();
      if (callback != null) callback();
    });

    // emit `connect_error`
    var errorSub = ON.on(socket, 'error', (data) {
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
    if (this._timeout != null) {
      var timeout = this._timeout;
      _logger.fine('connect attempt will timeout after $timeout');

      // set timer
      var timer = new Timer(new Duration(milliseconds: timeout), () {
        _logger.fine('connect attempt timed out after $timeout');
        openSub.destroy();
        socket.close();
        socket.emit('error', 'timeout');
        emitAll('connect_timeout', timeout);
      });

      this.subs.add(new Destroyable(() => timer?.cancel()));
    }

    this.subs.add(openSub);
    this.subs.add(errorSub);

    return this;
  }

  /**
     * Called upon transport open.
     *
     * @api private
     */
  onopen([_]) {
    _logger.fine('open');

    // clear old subs
    this.cleanup();

    // mark as open
    this.readyState = 'open';
    this.emit('open');

    // add new subs
    var socket = this.engine;
    this.subs.add(ON.on(socket, 'data', this.ondata));
    this.subs.add(ON.on(socket, 'ping', this.onping));
    this.subs.add(ON.on(socket, 'pong', this.onpong));
    this.subs.add(ON.on(socket, 'error', this.onerror));
    this.subs.add(ON.on(socket, 'close', this.onclose));
    this.subs.add(ON.on(this.decoder, 'decoded', this.ondecoded));
  }

  /**
     * Called upon a ping.
     *
     * @api private
     */
  onping([_]) {
    this.lastPing = new DateTime.now().millisecondsSinceEpoch;
    this.emitAll('ping');
  }

  /**
     * Called upon a packet.
     *
     * @api private
     */
  onpong([_]) {
    this.emitAll(
        'pong', new DateTime.now().millisecondsSinceEpoch - this.lastPing);
  }

  /**
     * Called with data.
     *
     * @api private
     */
  ondata(data) {
    this.decoder.add(data);
  }

  /**
     * Called when parser fully decodes a packet.
     *
     * @api private
     */
  ondecoded(packet) {
    this.emit('packet', packet);
  }

  /**
     * Called upon socket error.
     *
     * @api private
     */
  onerror(err) {
    _logger.fine('error $err');
    this.emitAll('error', err);
  }

  /**
     * Creates a new socket for the given `nsp`.
     *
     * @return {Socket}
     * @api public
     */
  Socket socket(String nsp, Map opts) {
    var socket = this.nsps[nsp];

    var onConnecting = ([_]) {
      if (!connecting.contains(socket)) {
        connecting.add(socket);
      }
    };

    if (socket == null) {
      socket = new Socket(this, nsp, opts);
      this.nsps[nsp] = socket;
      socket.on('connecting', onConnecting);
      socket.on('connect', (_) {
        socket.id = generateId(nsp);
      });

      if (this.autoConnect) {
        // manually call here since connecting event is fired before listening
        onConnecting();
      }
    }

    return socket;
  }

  /**
     * Called upon a socket close.
     *
     * @param {Socket} socket
     */
  destroy(socket) {
    this.connecting.remove(socket);
    if (this.connecting.isNotEmpty) return;

    this.close();
  }

  /**
     * Writes a packet.
     *
     * @param {Object} packet
     * @api private
     */
  packet(Map packet) {
    _logger.fine('writing packet $packet');
    if (packet.containsKey('query') && packet['type'] == 0)
      packet['nsp'] += '''?${packet['query']}''';

    if (encoding != true) {
      // encode, then write to engine with result
      encoding = true;
      this.encoder.encode(packet, (encodedPackets) {
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

  /**
     * If packet buffer is non-empty, begins encoding the
     * next packet in line.
     *
     * @api private
     */
  processPacketQueue() {
    if (this.packetBuffer.length > 0 && this.encoding != true) {
      var pack = this.packetBuffer.removeAt(0);
      this.packet(pack);
    }
  }

  /**
     * Clean up transport subscriptions and packet buffer.
     *
     * @api private
     */
  cleanup() {
    _logger.fine('cleanup');

    var subsLength = this.subs.length;
    for (var i = 0; i < subsLength; i++) {
      var sub = this.subs.removeAt(0);
      sub.destroy();
    }

    this.packetBuffer = [];
    this.encoding = false;
    this.lastPing = null;

    this.decoder.destroy();
  }

  /**
     * Close the current socket.
     *
     * @api private
     */
  close() => disconnect();

  disconnect() {
    _logger.fine('disconnect');
    this.skipReconnect = true;
    this.reconnecting = false;
    if ('opening' == this.readyState) {
      // `onclose` will not fire because
      // an open event never happened
      this.cleanup();
    }
    this.backoff.reset();
    this.readyState = 'closed';
    this.engine?.close();
  }

  /**
     * Called upon engine close.
     *
     * @api private
     */
  onclose(error) {
    _logger.fine('onclose');

    this.cleanup();
    this.backoff.reset();
    this.readyState = 'closed';
    this.emit('close', error['reason']);

    if (this._reconnection && !this.skipReconnect) {
      this.reconnect();
    }
  }

  /**
     * Attempt a reconnection.
     *
     * @api private
     */
  reconnect() {
    if (this.reconnecting || this.skipReconnect) return this;

    if (this.backoff.attempts >= this._reconnectionAttempts) {
      _logger.fine('reconnect failed');
      this.backoff.reset();
      this.emitAll('reconnect_failed');
      this.reconnecting = false;
    } else {
      var delay = this.backoff.duration;
      _logger.fine('will wait %dms before reconnect attempt', delay);

      this.reconnecting = true;
      var timer = new Timer(new Duration(milliseconds: delay), () {
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

      this.subs.add(new Destroyable(() => timer.cancel()));
    }
  }

  /**
     * Called upon successful reconnect.
     *
     * @api private
     */
  onreconnect() {
    var attempt = this.backoff.attempts;
    this.reconnecting = false;
    this.backoff.reset();
    this.updateSocketIds();
    this.emitAll('reconnect', attempt);
  }
}

/**
 * Initialize backoff timer with `opts`.
 *
 * - `min` initial timeout in milliseconds [100]
 * - `max` max timeout [10000]
 * - `jitter` [0]
 * - `factor` [2]
 *
 * @param {Object} opts
 * @api public
 */

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

  /**
   * Return the backoff duration.
   *
   * @return {Number}
   * @api public
   */
  num get duration {
    var ms = _ms * Math.pow(_factor, this.attempts++);
    if (_jitter > 0) {
      var rand = new Math.Random().nextDouble();
      var deviation = (rand * _jitter * ms).floor();
      ms = ((rand * 10).floor() & 1) == 0 ? ms - deviation : ms + deviation;
    }
    // #39: avoid an overflow with negative value
    return Math.max(Math.min(ms, _max), 0);
  }

  /**
   * Reset the number of attempts.
   *
   * @api public
   */
  void reset() {
    attempts = 0;
  }

  /**
   * Set the minimum duration
   *
   * @api public
   */
  set min(min) => _ms = min;

  /**
   * Set the maximum duration
   *
   * @api public
   */
  set max(max) => _max = max;

  /**
   * Set the jitter
   *
   * @api public
   */
  set jitter(jitter) => _jitter = jitter;
}
