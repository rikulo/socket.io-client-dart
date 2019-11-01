import 'dart:async';
import 'dart:html';

import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'package:socket_io_client/src/engine/transport/polling_transport.dart';

/**
 * xhr_transport.dart
 *
 * Purpose:
 *
 * Description:
 *
 * History:
 *   27/04/2017, Created by jumperchen
 *
 * Copyright (C) 2017 Potix Corporation. All Rights Reserved.
 */

final Logger _logger = new Logger('socket_io_client:transport.XHRTransport');

class XHRTransport extends PollingTransport {
  int requestTimeout;
  bool xd;
  bool xs;
  Request sendXhr;
  Request pollXhr;
  Map extraHeaders;

  /**
   * XHR Polling constructor.
   *
   * @param {Object} opts
   * @api public
   */
  XHRTransport(Map opts) : super(opts) {
    this.requestTimeout = opts['requestTimeout'];
    this.extraHeaders = opts['extraHeaders'] ?? <String, dynamic>{};

    var isSSL = 'https:' == window.location.protocol;
    var port = window.location.port;

    // some user agents have empty `location.port`
    if (port.isEmpty) {
      port = isSSL ? '443' : '80';
    }

    this.xd = opts['hostname'] != window.location.hostname ||
        int.parse(port) != opts['port'];
    this.xs = opts['secure'] != isSSL;
  }

  /**
   * XHR supports binary
   */
  bool supportsBinary = true;

  /**
   * Creates a request.
   *
   * @api private
   */
  request([Map opts]) {
    opts = opts ?? {};
    opts['uri'] = this.uri();
    opts['xd'] = this.xd;
    opts['xs'] = this.xs;
    opts['agent'] = this.agent ?? false;
    opts['supportsBinary'] = this.supportsBinary;
    opts['enablesXDR'] = this.enablesXDR;

    // SSL options for Node.js client
//    opts.pfx = this.pfx;
//    opts.key = this.key;
//    opts.passphrase = this.passphrase;
//    opts.cert = this.cert;
//    opts.ca = this.ca;
//    opts.ciphers = this.ciphers;
//    opts.rejectUnauthorized = this.rejectUnauthorized;
//    opts.requestTimeout = this.requestTimeout;

    // other options for Node.js client
    opts['extraHeaders'] = this.extraHeaders;

    return new Request(opts);
  }

  /**
   * Sends data.
   *
   * @param {String} data to send.
   * @param {Function} called upon flush.
   * @api private
   */
  doWrite(data, fn) {
    var isBinary = data is! String;
    var req =
        this.request({'method': 'POST', 'data': data, 'isBinary': isBinary});
    req.on('success', fn);
    req.on('error', (err) {
      onError('xhr post error', err);
    });
    this.sendXhr = req;
  }

  /**
   * Starts a poll cycle.
   *
   * @api private
   */
  doPoll() {
    _logger.fine('xhr poll');
    var req = this.request();
    req.on('data', (data) {
      onData(data);
    });
    req.on('error', (err) {
      onError('xhr poll error', err);
    });
    this.pollXhr = req;
  }
}

/**
 * Request constructor
 *
 * @param {Object} options
 * @api public
 */
class Request extends EventEmitter {
  String uri;
  bool xd;
  bool xs;
  bool async;
  var data;
  bool agent;
  bool isBinary;
  bool supportsBinary;
  bool enablesXDR;
  int requestTimeout;
  HttpRequest xhr;
  String method;
  StreamSubscription readyStateChange;
  Map extraHeaders;

  Request(Map opts) {
    this.method = opts['method'] ?? 'GET';
    this.uri = opts['uri'];
    this.xd = opts['xd'] == true;
    this.xs = opts['xs'] == true;
    this.async = opts['async'] != false;
    this.data = opts['data'];
    this.agent = opts['agent'];
    this.isBinary = opts['isBinary'];
    this.supportsBinary = opts['supportsBinary'];
    this.enablesXDR = opts['enablesXDR'];
    this.requestTimeout = opts['requestTimeout'];
    this.extraHeaders = opts['extraHeaders'];

    this.create();
  }

  /**
   * Creates the XHR object and sends the request.
   *
   * @api private
   */
  create() {
//var opts = { 'agent': this.agent, 'xdomain': this.xd, 'xscheme': this.xs, 'enablesXDR': this.enablesXDR };

    HttpRequest xhr = this.xhr = new HttpRequest();
    var self = this;

    try {
      _logger.fine('xhr open ${this.method}: ${this.uri}');
      xhr.open(this.method, this.uri, async: this.async);

      try {
        if (this.extraHeaders?.isNotEmpty == true) {
          this.extraHeaders.forEach((k, v) {
            xhr.setRequestHeader(k, v);
          });
        }
      } catch (e) {}

      if ('POST' == this.method) {
        try {
          if (this.isBinary) {
            xhr.setRequestHeader('Content-type', 'application/octet-stream');
          } else {
            xhr.setRequestHeader('Content-type', 'text/plain;charset=UTF-8');
          }
        } catch (e) {}
      }

      try {
        xhr.setRequestHeader('Accept', '*/*');
      } catch (e) {}

// ie6 check
//if ('withCredentials' in xhr) {
//xhr.withCredentials = true;
//}

      /*if (this.requestTimeout != null) {
        xhr.timeout = this.requestTimeout;
      }

      if (this.hasXDR()) {
        xhr.onload = function()
        {
          self.onLoad();
        };
        xhr.onerror = function()
        {
          self.onError(xhr.responseText);
        };
      } else {*/
      readyStateChange = xhr.onReadyStateChange.listen((evt) {
        if (xhr.readyState == 2) {
          var contentType;
          try {
            contentType = xhr.getResponseHeader('Content-Type');
          } catch (e) {}
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
      /*}*/

      _logger.fine('xhr data ${this.data}');
      xhr.send(this.data);
    } catch (e) {
// Need to defer since .create() is called directly fhrom the constructor
// and thus the 'error' event can only be only bound *after* this exception
// occurs.  Therefore, also, we cannot throw here at all.
      Timer.run(() => onError(e));
      return;
    }
  }

  /**
   * Called upon successful response.
   *
   * @api private
   */
  onSuccess() {
    this.emit('success');
    this.cleanup();
  }

  /**
   * Called if we have data.
   *
   * @api private
   */
  onData(data) {
    this.emit('data', data);
    this.onSuccess();
  }

  /**
   * Called upon error.
   *
   * @api private
   */
  onError(err) {
    this.emit('error', err);
    this.cleanup(true);
  }

  /**
   * Cleans up house.
   *
   * @api private
   */
  cleanup([fromError]) {
    if (this.xhr == null) {
      return;
    }
    // xmlhttprequest
    if (this.hasXDR()) {
    } else {
      readyStateChange?.cancel();
      readyStateChange = null;
    }

    if (fromError != null) {
      try {
        this.xhr.abort();
      } catch (e) {}
    }

    this.xhr = null;
  }

  /**
   * Called upon load.
   *
   * @api private
   */
  onLoad() {
    var data;
    try {
      var contentType;
      try {
        contentType = this.xhr.getResponseHeader('Content-Type');
      } catch (e) {}
      if (contentType == 'application/octet-stream') {
        data = this.xhr.response ?? this.xhr.responseText;
      } else {
        data = this.xhr.responseText;
      }
    } catch (e) {
      this.onError(e);
    }
    if (null != data) {
      if (data is ByteBuffer) data = data.asUint8List();
      this.onData(data);
    }
  }

  /**
   * Check if it has XDomainRequest.
   *
   * @api private
   */
  hasXDR() {
    // Todo: handle it in dart way
    return false;
    //  return 'undefined' !== typeof global.XDomainRequest && !this.xs && this.enablesXDR;
  }

  /**
   * Aborts the request.
   *
   * @api public
   */
  abort() => cleanup();
}
