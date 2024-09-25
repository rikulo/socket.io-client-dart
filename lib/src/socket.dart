//
// socket.dart
//
// Purpose:
//
// Description:
//
// History:
//   26/04/2017, Created by jumperchen
//
// Copyright (C) 2017 Potix Corporation. All Rights Reserved.
import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_client/src/manager.dart';
import 'package:socket_io_client/src/on.dart' as util;
import 'package:socket_io_common/src/parser/parser.dart';

const reservedEvents = <String, int>{
  'connect': 1,
  'connect_error': 1,
  'disconnect': 1,
  'disconnecting': 1,
  'newListener': 1,
  'removeListener': 1,
};

final Logger _logger = Logger('socket_io_client:Socket');

///
/// `Socket` constructor.
///
/// @api public
class Socket extends EventEmitter {
  Manager io;
  String? id;
  String? _pid;
  String? _lastOffset;
  bool connected = false;
  bool recovered = false;
  dynamic auth;
  List receiveBuffer = [];
  List sendBuffer = [];
  final List _queue = [];
  int _queueSeq = 0;

  String nsp;
  Map? _opts;
  num ids = 0;
  Map acks = {};
  List? subs;
  Map flags = {};
  String? query;
  final List _anyListeners = [];
  final List _anyOutgoingListeners = [];

  Socket(this.io, this.nsp, this._opts) {
    if (_opts != null) {
      query = _opts!['query'];
      auth = _opts!['auth'];
    }
    _opts ??= {};
    if (io.autoConnect) open();
  }

  /// Whether the socket is currently disconnected
  ///
  /// @example
  /// const socket = io();
  ///
  /// socket.on("connect", () => {
  ///   console.log(socket.disconnected); // false
  /// });
  ///
  /// socket.on("disconnect", () => {
  ///   console.log(socket.disconnected); // true
  /// });
  bool get disconnected => !connected;

  ///
  /// Subscribe to open, close and packet events
  ///
  /// @api private
  void subEvents() {
    if (subs?.isNotEmpty == true) return;

    var io = this.io;
    subs = [
      util.on(io, 'open', onopen),
      util.on(io, 'packet', onpacket),
      util.on(io, 'error', onerror),
      util.on(io, 'close', onclose)
    ];
  }

  /// Whether the Socket will try to reconnect when its Manager connects or reconnects
  bool get active {
    return subs != null;
  }

  ///
  /// "Opens" the socket.
  ///
  /// @api public
  Socket open() => connect();

  Socket connect() {
    if (connected) return this;
    subEvents();
    if (!io.reconnecting) {
      io.open(); // ensure open
    }
    if ('open' == io.readyState) onopen();
    return this;
  }

  ///
  /// Sends a `message` event.
  ///
  /// @return {Socket} self
  /// @api public
  Socket send(List args) {
    emit('message', args);
    return this;
  }

  ///
  /// Override `emit`.
  /// If the event is in `events`, it's emitted normally.
  ///
  /// @param {String} event name
  /// @return {Socket} self
  /// @api public
  @override
  void emit(String event, [data]) {
    emitWithAck(event, data);
  }

  ///
  /// Emits to this client.
  ///
  /// @return {Socket} self
  /// @api public
  void emitWithAck(String event, dynamic data,
      {Function? ack, bool binary = false}) {
    if (reservedEvents.containsKey(event)) {
      throw Exception('"$event" is a reserved event name');
    }
    var sendData = <dynamic>[event];
    if (data is ByteBuffer || data is List<int>) {
      sendData.add(data);
    } else if (data is Iterable) {
      sendData.addAll(data);
    } else if (data != null) {
      sendData.add(data);
    }

    if (_opts?['retries'] != null &&
        !flags.containsKey('fromQueue') &&
        !flags.containsKey('volatile')) {
      if (ack != null) {
        sendData.add(ack);
      }
      _addToQueue(sendData);
      return;
    }

    var packet = {
      'type': EVENT,
      'data': sendData,
      'options': {
        'compress': flags.isNotEmpty == true && (flags['compress'] ?? false)
      }
    };

    // event ack callback
    if (ack != null) {
      _logger.fine('emitting packet with ack id $ids');
      final id = ids++;
      _registerAckCallback(id.toInt(), ack);
      packet['id'] = '$id';
    }
    final isTransportWritable = io.engine != null &&
        io.engine!.transport != null &&
        io.engine!.transport!.writable == true;

    final discardPacket =
        flags['volatile'] != null && (!isTransportWritable || !connected);
    if (discardPacket) {
      _logger.fine('discard packet as the transport is not currently writable');
    } else if (connected) {
      notifyOutgoingListeners(packet);
      this.packet(packet);
    } else {
      sendBuffer.add(packet);
    }
    flags = {};
  }

  /// Emits an event and waits for an acknowledgement
  Future emitWithAckAsync(String event, dynamic data,
      {Function? ack, bool binary = false}) {
    var withErr = flags['timeout'] != null || _opts!['ackTimeout'] != null;
    var completer = Completer();

    emitWithAck(event, data, ack: (arg1, [arg2]) {
      if (withErr) {
        if (arg1 != null) {
          completer.completeError(arg1);
        } else {
          if (ack != null) ack(arg2);
          completer.complete(arg2);
        }
      } else {
        if (ack != null) ack(arg1);
        completer.complete(arg1);
      }
    }, binary: binary);
    return completer.future;
  }

  void _addToQueue(List<dynamic> args) {
    Function? ack;
    if (args.last is Function) {
      ack = args.removeLast() as Function?;
    }

    var packet = {
      'id': _queueSeq++,
      'tryCount': 0,
      'pending': false,
      'args': args,
      'flags': {...flags, 'fromQueue': true},
    };

    args.add((err, responseArgs) {
      if (packet != _queue.first) {
        // the packet has already been acknowledged
        return;
      }
      var hasError = err != null;
      if (hasError) {
        if (packet['tryCount'] is int &&
            _opts!['retries'] is int &&
            (packet['tryCount'] as int) > (_opts!['retries'] as int)) {
          _logger.fine(
              "packet [${packet['id']}] is discarded after ${packet['tryCount']} tries");
          _queue.removeAt(0);
          if (ack != null) {
            ack(err);
          }
        }
      } else {
        _logger.fine("packet [${packet['id']}] was successfully sent");
        _queue.removeAt(0);
        if (ack != null) {
          ack(null, responseArgs);
        }
      }
      packet['pending'] = false;
      return _drainQueue();
    });

    _queue.add(packet);
    _drainQueue();
  }

  void _drainQueue([bool force = false]) {
    _logger.fine("draining queue");
    if (!connected || _queue.isEmpty) {
      return;
    }
    var packet = _queue.first;
    if (packet['pending'] && !force) {
      _logger.fine(
          "packet [${packet['id']}] has already been sent and is waiting for an ack");
      return;
    }
    packet['pending'] = true;
    packet['tryCount']++;
    _logger
        .fine("sending packet [${packet['id']}] (try n°${packet['tryCount']})");
    flags = packet['flags'];
    var args = packet['args'] as List;
    final evt = args.removeAt(0);
    final ack = args.last is Function ? args.removeLast() : null;
    emitWithAck(evt, args, ack: ack);
  }

  void _registerAckCallback(int id, Function ack) {
    final sid = '$id';
    final timeout = flags['timeout'] ?? _opts?['ackTimeout'];
    if (timeout == null) {
      acks[sid] = ack;
      return;
    }

    var timer = Timer(Duration(milliseconds: timeout), () {
      acks.remove(sid);
      for (int i = 0; i < sendBuffer.length; i++) {
        if (sendBuffer[i]['id'] == sid) {
          _logger.fine("removing packet with ack id $sid from the buffer");
          sendBuffer.removeAt(i);
        }
      }
      _logger.fine("event with ack id $sid has timed out after $timeout ms");
      ack(Exception("operation has timed out"));
    });

    acks[sid] = (args) {
      timer.cancel();
      Function.apply(ack, [null, ...args]);
    };
  }

  void notifyOutgoingListeners(Map packet) {
    if (_anyOutgoingListeners.isNotEmpty) {
      final listeners = List.from(_anyOutgoingListeners);
      for (final listener in listeners) {
        Function.apply(listener, packet['data']);
      }
    }
  }

  ///
  /// Sends a packet.
  ///
  /// @param {Object} packet
  /// @api private
  void packet(Map packet) {
    packet['nsp'] = nsp;
    io.packet(packet);
  }

  ///
  /// Called upon engine `open`.
  ///
  /// @api private
  void onopen([_]) {
    _logger.fine('transport is open - connecting');

    if (auth is Function) {
      auth((data) {
        sendConnectPacket(data);
      });
    } else {
      sendConnectPacket(auth);
    }
  }

  /// Sends a CONNECT packet to initiate the Socket.IO session.
  ///
  /// @param {data}
  /// @api private
  void sendConnectPacket(Map? data) {
    packet({
      'type': CONNECT,
      'data': _pid != null
          ? {
              'pid': _pid,
              'offset': _lastOffset,
              ...(data ?? {}),
            }
          : data,
    });
  }

  /// Called upon engine or manager `error`
  void onerror(err) {
    if (!connected) {
      emitReserved('connect_error', err);
    }
  }

  ///
  /// Called upon engine `close`.
  ///
  /// @param {String} reason
  /// @api private
  void onclose(reason) {
    _logger.fine('close ($reason)');
    emitReserved('disconnecting', reason);
    connected = false;
    id = null;
    emitReserved('disconnect', reason);
  }

  ///
  /// Called with socket packet.
  ///
  /// @param {Object} packet
  /// @api private
  void onpacket(packet) {
    if (packet['nsp'] != nsp) return;

    switch (packet['type']) {
      case CONNECT:
        if (packet['data'] != null && packet['data']['sid'] != null) {
          final id = packet['data']['sid'];
          final pid = packet['data']['pid'];
          onconnect(id, pid);
        } else {
          emitReserved('connect_error',
              'It seems you are trying to reach a Socket.IO server in v2.x with a v3.x client, but they are not compatible (more information here: https://socket.io/docs/v3/migrating-from-2-x-to-3-0/)');
        }
        break;

      case EVENT:
      case BINARY_EVENT:
        onevent(packet);
        break;

      case ACK:
      case BINARY_ACK:
        onack(packet);
        break;

      case DISCONNECT:
        ondisconnect();
        break;

      case CONNECT_ERROR:
        destroy();
        emitReserved('error', packet['data']);
        break;
    }
  }

  ///
  /// Called upon a server event.
  ///
  /// @param {Object} packet
  /// @api private
  void onevent(Map packet) {
    List args = packet['data'] ?? [];
    _logger.fine('emitting event $args');

    if (null != packet['id']) {
      _logger.fine('attaching ack callback to event');
      args.add(ack(packet['id']));
    }

    // dart doesn't support "String... rest" syntax.
    if (connected == true) {
      emitEvent(args);
    } else {
      receiveBuffer.add(args);
    }
  }

  void emitEvent(List<dynamic> args) {
    if (_anyListeners.isNotEmpty) {
      final listeners = List.from(_anyListeners);
      for (final listener in listeners) {
        Function.apply(listener, args);
      }
    }
    // Assuming `super.emit` is analogous to calling an inherited or mixin method.
    if (args.length > 2) {
      Function.apply(super.emit, [args.first, args.sublist(1)]);
    } else {
      Function.apply(super.emit, args);
    }
    if (_pid != null && args.isNotEmpty && args.last.runtimeType == String) {
      _lastOffset = args.last;
    }
  }

  ///
  /// Produces an ack callback to emit with an event.
  ///
  /// @api private
  Function ack(id) {
    var sent = false;
    return (dynamic data) {
      // prevent double callbacks
      if (sent) return;
      sent = true;
      _logger.fine('sending ack $data');

      var sendData = <dynamic>[];
      if (data is ByteBuffer || data is List<int>) {
        sendData.add(data);
      } else if (data is Iterable) {
        sendData.addAll(data);
      } else if (data != null) {
        sendData.add(data);
      }

      packet({'type': ACK, 'id': id, 'data': sendData});
    };
  }

  ///
  /// Called upon a server acknowlegement.
  ///
  /// @param {Object} packet
  /// @api private
  void onack(Map packet) {
    var ack = acks.remove('${packet['id']}');
    if (ack is Function) {
      _logger.fine('''calling ack ${packet['id']} with ${packet['data']}''');

      var args = packet['data'] as List;
      if (args.length > 1) {
        // Fix for #42 with nodejs server
        Function.apply(ack, [args]);
      } else {
        Function.apply(ack, args);
      }
    } else {
      _logger.fine('''bad ack ${packet['id']}''');
    }
  }

  ///
  /// Called upon server connect.
  ///
  /// @api private
  void onconnect(id, pid) {
    this.id = id;
    recovered = pid != null && _pid == pid;
    _pid = pid; // defined only if connection state recovery is enabled
    connected = true;
    emitBuffered();
    emitReserved("connect");
    _drainQueue(true);
  }

  ///
  /// Emit buffered events (received and emitted).
  ///
  /// @api private
  void emitBuffered() {
    for (var args in receiveBuffer) {
      emitEvent(args);
    }
    receiveBuffer = [];

    for (var packet in sendBuffer) {
      notifyOutgoingListeners(packet);
      this.packet(packet);
    }
    sendBuffer = [];
  }

  ///
  /// Called upon server disconnect.
  ///
  /// @api private
  void ondisconnect() {
    _logger.fine('server disconnect ($nsp)');
    destroy();
    onclose('io server disconnect');
  }

  ///
  /// Called upon forced client/server side disconnections,
  /// this method ensures the manager stops tracking us and
  /// that reconnections don't get triggered for this.
  ///
  /// @api private.

  void destroy() {
    final subs0 = subs;
    if (subs0 != null && subs0.isNotEmpty) {
      // clean subscriptions to avoid reconnections

      for (var i = 0; i < subs0.length; i++) {
        subs0[i].destroy();
      }
      subs = null;
    }

    io.destroy(this);
  }

  ///
  /// Disconnects the socket manually.
  ///
  /// @return {Socket} self
  /// @api public
  Socket close() => disconnect();

  Socket disconnect() {
    if (connected == true) {
      _logger.fine('performing disconnect ($nsp)');
      packet({'type': DISCONNECT});
    }

    // remove socket from pool
    destroy();

    if (connected == true) {
      // fire events
      onclose('io client disconnect');
    }
    return this;
  }

  /// Disposes the socket manually which will destroy, close, disconnect the socket connection
  /// and clear all the event listeners. Unlike [close] or [disconnect] which won't clear
  /// all the event listeners
  ///
  /// @since 0.9.11
  void dispose() {
    disconnect();
    clearListeners();
  }

  ///
  /// Sets the compress flag.
  ///
  /// @param {Boolean} if `true`, compresses the sending data
  /// @return {Socket} self
  /// @api public
  Socket compress(compress) {
    flags['compress'] = compress;
    return this;
  }

  /// Sets a modifier for a subsequent event emission that the event message will be dropped when this socket is not
  /// ready to send messages.
  ///
  /// @example
  /// socket.volatile.emit("hello"); // the server may or may not receive it
  ///
  /// @returns self
  Socket get volatile {
    flags['volatile'] = true;
    return this;
  }

  /// Sets a modifier for a subsequent event emission that the callback will be called with an error when the
  /// given number of milliseconds have elapsed without an acknowledgement from the server:
  ///
  /// @example
  /// socket.timeout(5000).emit("my-event", (err) => {
  ///   if (err) {
  ///     // the server did not acknowledge the event in the given delay
  ///   }
  /// });
  ///
  /// @returns self
  Socket timeout(int timeout) {
    flags['timeout'] = timeout;
    return this;
  }

  /// Adds a listener that will be fired when any event is emitted. The event name is passed as the first argument to the
  /// callback.
  ///
  /// @example
  /// socket.onAny((event, ...args) => {
  ///   console.log(`got ${event}`);
  /// });
  ///
  /// @param listener
  @override
  Socket onAny(AnyEventHandler handler) {
    _anyListeners.add(handler);
    return this;
  }

  /// Adds a listener that will be fired when any event is emitted. The event name is passed as the first argument to the
  /// callback. The listener is added to the beginning of the listeners array.
  ///
  /// @example
  /// socket.prependAny((event, ...args) => {
  ///   console.log(`got event ${event}`);
  /// });
  ///
  /// @param listener
  Socket prependAny(AnyEventHandler handler) {
    _anyListeners.insert(0, handler);
    return this;
  }

  /// Removes the listener that will be fired when any event is emitted.
  ///
  /// @example
  /// const catchAllListener = (event, ...args) => {
  ///   console.log(`got event ${event}`);
  /// }
  ///
  /// socket.onAny(catchAllListener);
  ///
  /// // remove a specific listener
  /// socket.offAny(catchAllListener);
  ///
  /// // or remove all listeners
  /// socket.offAny();
  ///
  /// @param listener
  @override
  Socket offAny([AnyEventHandler? handler]) {
    if (handler != null) {
      _anyListeners.remove(handler);
    } else {
      _anyListeners.clear();
    }
    return this;
  }

  /// Returns an array of listeners that are listening for any event that is specified. This array can be manipulated,
  /// e.g. to remove listeners.
  List listenersAny() {
    return _anyListeners;
  }

  /// Adds a listener that will be fired when any event is emitted. The event name is passed as the first argument to the
  /// callback.
  ///
  /// Note: acknowledgements sent to the server are not included.
  ///
  /// @example
  /// socket.onAnyOutgoing((event, ...args) => {
  ///   console.log(`sent event ${event}`);
  /// });
  ///
  /// @param listener
  Socket onAnyOutgoing(AnyEventHandler handler) {
    _anyOutgoingListeners.add(handler);
    return this;
  }

  /// Adds a listener that will be fired when any event is emitted. The event name is passed as the first argument to the
  /// callback. The listener is added to the beginning of the listeners array.
  ///
  /// Note: acknowledgements sent to the server are not included.
  ///
  /// @example
  /// socket.prependAnyOutgoing((event, ...args) => {
  ///   console.log(`sent event ${event}`);
  /// });
  ///
  /// @param listener
  Socket prependAnyOutgoing(AnyEventHandler handler) {
    _anyOutgoingListeners.insert(0, handler);
    return this;
  }

  /// Removes the listener that will be fired when any event is emitted.
  ///
  /// @example
  /// const catchAllListener = (event, ...args) => {
  ///   console.log(`sent event ${event}`);
  /// }
  ///
  /// socket.onAnyOutgoing(catchAllListener);
  ///
  /// // remove a specific listener
  /// socket.offAnyOutgoing(catchAllListener);
  ///
  /// // or remove all listeners
  /// socket.offAnyOutgoing();
  ///
  /// @param [listener] - the catch-all listener (optional)
  Socket offAnyOutgoing([AnyEventHandler? handler]) {
    if (handler != null) {
      _anyOutgoingListeners.remove(handler);
    } else {
      _anyOutgoingListeners.clear();
    }
    return this;
  }

  /// Returns an array of listeners that are listening for any event that is specified. This array can be manipulated,
  /// e.g. to remove listeners.
  List listenersAnyOutgoing() {
    return _anyOutgoingListeners;
  }
}
