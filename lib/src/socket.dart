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
import 'package:logging/logging.dart';
import 'package:socket_io/src/util/event_emitter.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/on.dart' as ON;
import 'package:socket_io/src/parser/parser.dart';

/**
 * Internal events (blacklisted).
 * These events can't be emitted by the user.
 *
 * @api private
 */

const List EVENTS = const [
  'connect',
  'connect_error',
  'connect_timeout',
  'connecting',
  'disconnect',
  'error',
  'reconnect',
  'reconnect_attempt',
  'reconnect_failed',
  'reconnect_error',
  'reconnecting',
  'ping',
  'pong'
];

final Logger _logger = new Logger('socket_io_client:Socket');

/**
 * `Socket` constructor.
 *
 * @api public
 */
class Socket extends EventEmitter {
  String nsp;
  Map opts;

  Manager io;
  Socket json;
  num ids;
  Map acks;
  bool connected;
  bool disconnected;
  List sendBuffer;
  List receiveBuffer;
  String query;
  List subs;
  Map flags;
  String id;

  Socket(this.io, this.nsp, this.opts) {
    this.json = this; // compat
    this.ids = 0;
    this.acks = {};
    this.receiveBuffer = [];
    this.sendBuffer = [];
    this.connected = false;
    this.disconnected = true;
    if (opts != null) {
      this.query = opts['query'];
    }
    if (this.io.autoConnect) this.open();
  }

  /**
   * Subscribe to open, close and packet events
   *
   * @api private
   */
  subEvents() {
    if (this.subs?.isEmpty == true) return;

    var io = this.io;
    this.subs = [
      ON.on(io, 'open', this.onopen),
      ON.on(io, 'packet', this.onpacket),
      ON.on(io, 'close', this.onclose)
    ];
  }

  /**
   * "Opens" the socket.
   *
   * @api public
   */
  open() => connect();

  connect() {
    if (this.connected == true) return this;
    this.subEvents();
    this.io.open(); // ensure open
    if ('open' == this.io.readyState) this.onopen();
    this.emit('connecting');
    return this;
  }

  /**
   * Sends a `message` event.
   *
   * @return {Socket} self
   * @api public
   */
  send(List args) {
    this.emit('message', args);
    return this;
  }

  /**
   * Override `emit`.
   * If the event is in `events`, it's emitted normally.
   *
   * @param {String} event name
   * @return {Socket} self
   * @api public
   */
  void emit(String event, [data]) {
    emitWithAck(event, data);
  }

  /**
   * Emits to this client.
   *
   * @return {Socket} self
   * @api public
   */
  void emitWithAck(String event, dynamic data, {Function ack}) {
    if (EVENTS.contains(event)) {
      super.emit(event, data);
    } else {
      List sendData = data == null ? [event] : [event, data];

      var packet = {
        'type': EVENT,
        'data': sendData,
        'options': {
          'compress': this.flags?.isNotEmpty == true && this.flags['compress']
        }
      };

      // event ack callback
      if (ack != null) {
        _logger.fine('emitting packet with ack id $ids');
        this.acks['${this.ids}'] = ack;
        packet['id'] = '${this.ids++}';
      }

      if (this.connected == true) {
        this.packet(packet);
      } else {
        this.sendBuffer.add(packet);
      }
      this.flags = null;
    }
  }

  /**
   * Sends a packet.
   *
   * @param {Object} packet
   * @api private
   */
  packet(Map packet) {
    packet['nsp'] = this.nsp;
    this.io.packet(packet);
  }

  /**
   * Called upon engine `open`.
   *
   * @api private
   */
  onopen([_]) {
    _logger.fine('transport is open - connecting');

    // write connect packet if necessary
    if ('/' != this.nsp) {
      if (this.query?.isNotEmpty == true) {
        this.packet({'type': CONNECT, 'query': this.query});
      } else {
        this.packet({'type': CONNECT});
      }
    }
  }

  /**
   * Called upon engine `close`.
   *
   * @param {String} reason
   * @api private
   */
  onclose(String reason) {
    _logger.fine('close ($reason)');
    this.emit('disconnecting', reason);
    this.connected = false;
    this.disconnected = true;
    this.id = null;
    this.emit('disconnect', reason);
  }

  /**
   * Called with socket packet.
   *
   * @param {Object} packet
   * @api private
   */
  onpacket(Map packet) {
    if (packet['nsp'] != this.nsp) return;

    switch (packet['type']) {
      case CONNECT:
        this.onconnect();
        break;

      case EVENT:
        this.onevent(packet);
        break;

      case BINARY_EVENT:
        this.onevent(packet);
        break;

      case ACK:
        this.onack(packet);
        break;

      case BINARY_ACK:
        this.onack(packet);
        break;

      case DISCONNECT:
        this.ondisconnect();
        break;

      case ERROR:
        this.emit('error', packet['data']);
        break;
    }
  }

  /**
   * Called upon a server event.
   *
   * @param {Object} packet
   * @api private
   */
  onevent(Map packet) {
    List args = packet['data'] ?? [];
//    debug('emitting event %j', args);

    if (null != packet['id']) {
//      debug('attaching ack callback to event');
      args.add(this.ack(packet['id']));
    }

    // dart doesn't support "String... rest" syntax.
    if (this.connected == true) {
      if (args.length > 2) {
        Function.apply(super.emit, [args.first, args.sublist(1)]);
      } else {
        Function.apply(super.emit, args);
      }
    } else {
      this.receiveBuffer.add(args);
    }
  }

  /**
   * Produces an ack callback to emit with an event.
   *
   * @api private
   */
  Function ack(id) {
    var sent = false;
    return (_) {
      // prevent double callbacks
      if (sent) return;
      sent = true;
      _logger.fine('sending ack $_');

      packet({'type': ACK, 'id': id, 'data': [_]});
    };
  }

  /**
   * Called upon a server acknowlegement.
   *
   * @param {Object} packet
   * @api private
   */
  onack(Map packet) {
    var ack = this.acks.remove(packet['id']);
    if (ack is Function) {
      _logger.fine('''calling ack ${packet['id']} with ${packet['data']}''');
      Function.apply(ack, packet['data']);
    } else {
      _logger.fine('''bad ack ${packet['id']}''');
    }
  }

  /**
   * Called upon server connect.
   *
   * @api private
   */
  onconnect() {
    this.connected = true;
    this.disconnected = false;
    this.emit('connect');
    this.emitBuffered();
  }

  /**
   * Emit buffered events (received and emitted).
   *
   * @api private
   */
  emitBuffered() {
    var i;
    for (i = 0; i < this.receiveBuffer.length; i++) {
      Function.apply(this.emit, this.receiveBuffer[i]);
    }
    this.receiveBuffer = [];

    for (i = 0; i < this.sendBuffer.length; i++) {
      this.packet(this.sendBuffer[i]);
    }
    this.sendBuffer = [];
  }

  /**
   * Called upon server disconnect.
   *
   * @api private
   */
  ondisconnect() {
    _logger.fine('server disconnect (${this.nsp})');
    this.destroy();
    this.onclose('io server disconnect');
  }

  /**
   * Called upon forced client/server side disconnections,
   * this method ensures the manager stops tracking us and
   * that reconnections don't get triggered for this.
   *
   * @api private.
   */

  destroy() {
    if (this.subs?.isNotEmpty == true) {
      // clean subscriptions to avoid reconnections
      for (var i = 0; i < this.subs.length; i++) {
        this.subs[i].destroy();
      }
      this.subs = null;
    }

    this.io.destroy(this);
  }

  /**
   * Disconnects the socket manually.
   *
   * @return {Socket} self
   * @api public
   */
  close() => disconnect();

  disconnect() {
    if (this.connected == true) {
      _logger.fine('performing disconnect (${this.nsp})');
      this.packet({'type': DISCONNECT});
    }

    // remove socket from pool
    this.destroy();

    if (this.connected == true) {
      // fire events
      this.onclose('io client disconnect');
    }
    return this;
  }

  /**
   * Sets the compress flag.
   *
   * @param {Boolean} if `true`, compresses the sending data
   * @return {Socket} self
   * @api public
   */
  compress(compress) {
    this.flags = this.flags ??= {};
    this.flags['compress'] = compress;
    return this;
  }
}