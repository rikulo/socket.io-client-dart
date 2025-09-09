//
// polling_transport.dart
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
import 'dart:js_interop';
import 'package:web/web.dart';

import 'package:logging/logging.dart';
import 'package:socket_io_client/src/engine/transport.dart';
import 'package:socket_io_common/src/engine/parser/parser.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';

final Logger _logger = Logger('socket_io:transport.PollingTransport');

bool _hasXHR2() {
  try {
    // Dart's HttpRequest doesn't expose a direct way to check for XHR2 features,
    // but attempting to use features like setting `responseType` could serve as a proxy.
    final xhr = XMLHttpRequest();
    xhr.responseType =
        'arraybuffer'; // Attempting to set a responseType supported by XHR2
    return true;
  } catch (e) {
    return false;
  }
}

class PollingTransport extends Transport {
  ///
  /// Transport name.
  @override
  String? name = 'polling';

  bool polling = false;
  dynamic pollXhr;
  dynamic cookieJar;
  late bool xd;

  ///
  /// XHR Polling constructor.
  PollingTransport(Map opts) : super(opts) {
    final isSSL = window.location.protocol == 'https:';
    String port = window.location.port;

    if (port.isEmpty) {
      port = isSSL ? '443' : '80';
    }

    xd = opts['hostname'] != window.location.hostname || port != opts['port'];
    // Force base64 is a specific strategy that might not have a direct equivalent in Dart.
    // Assuming it's a flag that disables binary data transfer in favor of base64 encoded strings.
    final forceBase64 = opts.containsKey('forceBase64') && opts['forceBase64'];
    supportsBinary = _hasXHR2() && !forceBase64;

    if (opts.containsKey('withCredentials') && opts['withCredentials']) {
      // Dart in a browser environment handles cookies automatically,
      // and you might not need to manually manage a cookie jar.
      // However, for setting credentials like cookies in requests, you would use the
      // `withCredentials` property of `HttpRequest`.
      // this.cookieJar = createCookieJar();
    }
  }

  ///
  /// Opens the socket (triggers polling). We write a PING message to determine
  /// when the transport is open.
  ///
  /// @api private
  @override
  void doOpen() {
    poll();
  }

  ///
  /// Pauses polling.
  ///
  /// @param {Function} callback upon buffers are flushed and transport is paused
  /// @api private
  @override
  void pause(onPause) {
    var self = this;

    readyState = 'pausing';

    pause() {
      _logger.fine('paused');
      self.readyState = 'paused';
      onPause();
    }

    if (polling == true || writable != true) {
      var total = 0;

      if (polling == true) {
        _logger.fine('we are currently polling - waiting to pause');
        total++;
        once('pollComplete', (_) {
          _logger.fine('pre-pause polling complete');
          if (--total == 0) pause();
        });
      }

      if (writable != true) {
        _logger.fine('we are currently writing - waiting to pause');
        total++;
        once('drain', (_) {
          _logger.fine('pre-pause writing complete');
          if (--total == 0) pause();
        });
      }
    } else {
      pause();
    }
  }

  ///
  /// Starts polling cycle.
  ///
  /// @api public
  void poll() {
    _logger.fine('polling');
    polling = true;
    doPoll();
    emitReserved('poll');
  }

  ///
  /// Overloads onData to detect payloads.
  ///
  /// @api private
  @override
  void onData(data) {
    var self = this;
    _logger.fine('polling got data $data');
    callback(packet, [index, total]) {
      // if its the first message we consider the transport open
      if ('opening' == self.readyState && packet['type'] == 'open') {
        self.onOpen();
      }

      // if its a close packet, we close the ongoing requests
      if ('close' == packet['type']) {
        self.onClose({'description': "transport closed by the server"});
        return false;
      }

      // otherwise bypass onData and handle the message
      self.onPacket(packet);
    }

    // decode payload
    PacketParser.decodePayload(data, socket!.binaryType).forEach(callback);

    // if an event did not trigger closing
    if ('closed' != readyState) {
      // if we got data we're not polling
      polling = false;
      emitReserved('pollComplete');

      if ('open' == readyState) {
        poll();
      } else {
        _logger.fine('ignoring poll - transport state "$readyState"');
      }
    }
  }

  ///
  /// For polling, send a close packet.
  ///
  /// @api private
  @override
  void doClose() {
    var self = this;

    close([_]) {
      _logger.fine('writing close packet');
      self.write([
        {'type': 'close'}
      ]);
    }

    if ('open' == readyState) {
      _logger.fine('transport open - closing');
      close();
    } else {
      // in case we're trying to close while
      // handshaking is in progress (GH-164)
      _logger.fine('transport not open - deferring close');
      once('open', close);
    }
  }

  ///
  /// Writes a packets payload.
  ///
  /// @param {Array} data packets
  /// @param {Function} drain callback
  /// @api private
  @override
  void write(List packets) {
    var self = this;
    writable = false;

    PacketParser.encodePayload(packets, callback: (data) {
      self.doWrite(data, (_) {
        self.writable = true;
        self.emitReserved('drain');
      });
    });
  }

  ///
  /// Generates uri for connection.
  ///
  /// @api private
  String uri() {
    final query = this.query ?? {};
    var schema = opts['secure'] ? 'https' : 'http';

    // cache busting is forced
    if (opts['timestampRequests'] != null) {
      query[opts['timestampParam']] =
          DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    }

    if (supportsBinary == false && !query.containsKey('sid')) {
      query['b64'] = 1;
    }

    return createUri(schema, query);
  }

  Request request([Map? opts]) {
    opts = opts ?? {};
    final mergedOpts = {
      ...opts,
      xd: xd,
      cookieJar: cookieJar,
      ...this.opts,
      'withCredentials': this.opts['withCredentials'] ?? false,
    };
    return Request(uri(), mergedOpts);
  }

  ///
  /// Sends data.
  ///
  /// @param {String} data to send.
  /// @param {Function} called upon flush.
  /// @api private
  void doWrite(data, fn) {
    var isBinary = data is! String;
    var req = request({'method': 'POST', 'data': data, 'isBinary': isBinary});
    req.on('success', fn);
    req.on('error', (err) {
      onError('xhr post error', err);
    });
  }

  ///
  /// Starts a poll cycle.
  ///
  /// @api private
  void doPoll() {
    _logger.fine('xhr poll');
    var req = request();
    req.on('data', (data) {
      onData(data);
    });
    req.on('error', (xhrStatus) {
      onError('xhr poll error', xhrStatus);
    });
    pollXhr = req;
  }
}

class Request extends EventEmitter {
  late Map opts;
  late String method;
  late String uri;
  late String? data;

  XMLHttpRequest? xhr;
  int? index;
  StreamSubscription? readyStateChange;

  Request(this.uri, this.opts) {
    method = opts['method'] ?? 'GET';
    data = opts['data'];

    create();
  }

  ///
  /// Creates the XHR object and sends the request.
  ///
  /// @api private
  void create() {
    final opts = {
      'agent': this.opts['agent'],
      'pfx': this.opts['pfx'],
      'key': this.opts['key'],
      'passphrase': this.opts['passphrase'],
      'cert': this.opts['cert'],
      'ca': this.opts['ca'],
      'ciphers': this.opts['ciphers'],
      'rejectUnauthorized': this.opts['rejectUnauthorized'],
      'autoUnref': this.opts['autoUnref'],
    };
    opts['xdomain'] = this.opts['xd'] ?? false;

    var xhr = this.xhr = XMLHttpRequest();
    var self = this;

    try {
      _logger.fine('xhr open $method: $uri');
      xhr.open(method, uri, true);

      try {
        if (this.opts.containsKey('extraHeaders') &&
            this.opts['extraHeaders']?.isNotEmpty == true) {
          this.opts['extraHeaders'].forEach((k, v) {
            xhr.setRequestHeader(k, v);
          });
        }
      } catch (e) {
        // ignore
      }

      if ('POST' == method) {
        try {
          xhr.setRequestHeader('Content-type', 'text/plain;charset=UTF-8');
        } catch (e) {
          // ignore
        }
      }

      try {
        xhr.setRequestHeader('Accept', '*/*');
      } catch (e) {
        // ignore
      }
      this.opts['cookieJar']?.addCookies(xhr);

      if (this.opts.containsKey('requestTimeout')) {
        xhr.timeout = this.opts['requestTimeout'];
      }

      readyStateChange = xhr.onReadyStateChange.listen((evt) {
        if (xhr.readyState == 2) {
          dynamic contentType;
          try {
            contentType = xhr.getResponseHeader('Content-Type');
          } catch (e) {
            // ignore
          }
          if (contentType == 'application/octet-stream') {
            xhr.responseType = 'arraybuffer';
          }
        }
        if (4 != xhr.readyState) return;
        if (200 == xhr.status || 1223 == xhr.status) {
          self.onLoad();
        } else {
          // make sure the `error` event handler that's user-set
          // does not throw in the same tick and gets caught here
          Timer.run(() => self.onError(xhr.status));
        }
      });

      _logger.fine('xhr data $data');
      xhr.withCredentials = this.opts['withCredentials'] == true;
      xhr.send(data?.jsify());
    } catch (e) {
      // Need to defer since .create() is called directly fhrom the constructor
      // and thus the 'error' event can only be only bound *after* this exception
      // occurs.  Therefore, also, we cannot throw here at all.
      Timer.run(() => onError(e));
      return;
    }
  }

  ///
  /// Called upon error.
  ///
  /// @api private
  void onError(err) {
    emitReserved('error', err);
    cleanup(true);
  }

  ///
  /// Cleans up house.
  ///
  /// @api private
  void cleanup([fromError]) {
    if (xhr == null) {
      return;
    }

    readyStateChange?.cancel();
    readyStateChange = null;

    if (fromError != null) {
      try {
        xhr!.abort();
      } catch (e) {
        // ignore
      }
    }

    xhr = null;
  }

  ///
  /// Called upon load.
  ///
  /// @api private
  void onLoad() {
    final data = xhr!.responseText;
    if (data.isNotEmpty) {
      emitReserved('data', data);
      emitReserved('success');
      cleanup();
    }
  }

  ///
  /// Aborts the request.
  ///
  /// @api public
  void abort() => cleanup();
}
