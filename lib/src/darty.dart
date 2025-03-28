// Copyright (C) 2020 Potix Corporation. All Rights Reserved
// History: 2020/11/27 11:47 AM
// Author: jumperchen<jumperchen@potix.com>

import 'package:socket_io_client/socket_io_client.dart';
import 'package:socket_io_common/socket_io_common.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';

/// Default event listeners for dart way API.
extension DartySocket on Socket {
  Function() onConnect(EventHandler handler) {
    return on('connect', handler);
  }

  Function() onConnectError(EventHandler handler) {
    return on('connect_error', handler);
  }

  Function() onDisconnect(EventHandler handler) {
    return on('disconnect', handler);
  }

  Function() onError(EventHandler handler) {
    return this.io.on('error', handler);
  }

  Function() onReconnect(EventHandler handler) {
    return this.io.on('reconnect', handler);
  }

  Function() onReconnectAttempt(EventHandler handler) {
    return this.io.on('reconnect_attempt', handler);
  }

  Function() onReconnectFailed(EventHandler handler) {
    return this.io.on('reconnect_failed', handler);
  }

  Function() onReconnectError(EventHandler handler) {
    return this.io.on('reconnect_error', handler);
  }

  Function() onPing(EventHandler handler) {
    return this.io.on('ping', handler);
  }

  Function() onPong(EventHandler handler) {
    return on('pong', handler);
  }
}

/// Parser options
class ParserOptions {
  final Encoder Function() encoder;
  final Decoder Function() decoder;

  ParserOptions({required this.encoder, required this.decoder});
}

/// Option Builder to help developer to construct an options map.
class OptionBuilder {
  final Map<String, dynamic> _opts;

  OptionBuilder() : _opts = <String, dynamic>{};

  /// Whether to enable to create a new Manager instance.
  /// The default is false
  OptionBuilder enableForceNew() {
    _opts['forceNew'] = true;
    return this;
  }

  /// Whether to disable to create a new Manager instance.
  OptionBuilder disableForceNew() {
    _opts.remove('forceNew');
    return this;
  }

  OptionBuilder enableForceNewConnection() {
    _opts['force new connection'] = true;
    return this;
  }

  OptionBuilder disableForceNewConnection() {
    _opts.remove('force new connection');
    return this;
  }

  /// The opposite of forceNew: whether to reuse an existing Manager instance.
  /// The default is true.
  OptionBuilder enableMultiplex() {
    _opts['multiplex'] = true;
    return this;
  }

  /// Whether to disable multiplexing.
  OptionBuilder disableMultiplex() {
    _opts.remove('multiplex');
    return this;
  }

  /// Enable the trailing slash which was added by default
  OptionBuilder enableAddTrailingSlash() {
    _opts['addTrailingSlash'] = true;
    return this;
  }

  /// Disable the trailing slash which was added by default
  OptionBuilder disableAddTrailingSlash() {
    _opts.remove('addTrailingSlash');
    return this;
  }

  /// Additional query parameters
  OptionBuilder setQuery(Map query) {
    _opts['query'] = query;
    return this;
  }

  /// It is the name of the path that is captured on the server side.
  /// The default is "/socket.io/".
  OptionBuilder setPath(String path) {
    _opts['path'] = path;
    return this;
  }

  /// Either a single protocol string or an array of protocol strings.
  /// These strings are used to indicate sub-protocols, so that a single server
  /// can implement multiple WebSocket sub-protocols
  OptionBuilder setProtocols(List<String> protocols) {
    _opts['protocols'] = protocols;
    return this;
  }

  /// If true and if the previous WebSocket connection to the server succeeded,
  /// the connection attempt will bypass the normal upgrade process and will
  /// initially try WebSocket. A connection attempt following a transport error
  /// will use the normal upgrade process. It is recommended you turn this on
  /// only when using SSL/TLS connections, or if you know that your network does
  /// not block websockets.
  /// The default is false.
  OptionBuilder setRememberUpgrade(bool rememberUpgrade) {
    _opts['rememberUpgrade'] = rememberUpgrade;
    return this;
  }

  /// The name of the query parameter to use as our timestamp key.
  /// The default is "t".
  OptionBuilder setTimestampParam(String timestampParam) {
    _opts['timestampParam'] = timestampParam;
    return this;
  }

  /// Whether to add the timestamp query param to each request
  /// The default is true.
  OptionBuilder setTimestampRequests(bool timestampRequests) {
    _opts['timestampRequests'] = timestampRequests;
    return this;
  }

  /// Transport-specific options.
  OptionBuilder setTransportOptions(Map<String, dynamic> transportOptions) {
    _opts['transportOptions'] = transportOptions;
    return this;
  }

  /// Enable auto connect.
  /// The default is true.
  OptionBuilder enableAutoConnect() {
    _opts.remove('autoConnect');
    return this;
  }

  /// Disable auto connect.
  OptionBuilder disableAutoConnect() {
    _opts['autoConnect'] = false;
    return this;
  }

  /// The parser used to marshall/unmarshall packets for transport.
  OptionBuilder setParser(ParserOptions parserOptions) {
    _opts['parser'] = parserOptions;
    return this;
  }

  /// The number of reconnection attempts before giving up.
  /// The default is Infinity.
  OptionBuilder setReconnectionAttempts(num attempts) {
    _opts['reconnectionAttempts'] = attempts;
    return this;
  }

  /// The initial delay before reconnection in milliseconds
  /// (affected by the randomizationFactor value).
  /// The default is 1000 (1 second).
  OptionBuilder setReconnectionDelay(int delay) {
    _opts['reconnectionDelay'] = delay;
    return this;
  }

  /// The maximum delay between two reconnection attempts. Each attempt
  /// increases the reconnection delay by 2x.
  /// The default is 5000 (5 seconds).
  OptionBuilder setReconnectionDelayMax(int delayMax) {
    _opts['reconnectionDelayMax'] = delayMax;
    return this;
  }

  /// The randomization factor used to compute the actual reconnection
  /// The default is 0.5.
  OptionBuilder setRandomizationFactor(num factor) {
    _opts['randomizationFactor'] = factor;
    return this;
  }

  /// The timeout in milliseconds for each connection attempt.
  /// The default is 20000 (20 seconds).
  OptionBuilder setTimeout(int timeout) {
    _opts['timeout'] = timeout;
    return this;
  }

  /// Whether to reconnect automatically.
  /// The default is true.
  OptionBuilder enableReconnection() {
    _opts.remove('reconnection');
    return this;
  }

  /// Whether reconnection is disabled.
  OptionBuilder disableReconnection() {
    _opts['reconnection'] = false;
    return this;
  }

  /// The low-level connection to the Socket.IO server can either be established with:
  /// Default value: ["polling", "websocket", "webtransport"]
  /// Note: "webtransport" is not supported in dart yet.
  OptionBuilder setTransports(List<String> transports) {
    _opts['transports'] = transports;
    return this;
  }

  /// Whether the client should try to upgrade the transport from HTTP long-polling to something better.
  /// The default is true.
  OptionBuilder setUpgrade(bool upgrade) {
    _opts['upgrade'] = upgrade;
    return this;
  }

  /// Additional headers to be sent during the handshake.
  OptionBuilder setExtraHeaders(Map<String, dynamic> headers) {
    _opts['extraHeaders'] = headers;
    return this;
  }

  /// Whether to force base 64 encoding for transport.
  /// The default is false.
  OptionBuilder setForceBase64(bool forceBase64) {
    _opts['forceBase64'] = forceBase64;
    return this;
  }

  /// The default timeout in milliseconds
  /// used when waiting for an acknowledgement (not to be mixed up with the already
  /// existing timeout option, which is used by the Manager during the connection)
  OptionBuilder setAckTimeout(int timeout) {
    _opts['ackTimeout'] = timeout;
    return this;
  }

  OptionBuilder setAuth(Map auth) {
    _opts['auth'] = auth;
    return this;
  }

  OptionBuilder setAuthFn(
      void Function(void Function(Map auth) callback) authFn) {
    _opts['auth'] = authFn;
    return this;
  }

  /// The maximum number of retries. Above the limit, the packet will be discarded.
  OptionBuilder setRetries(int retries) {
    _opts['retries'] = retries;
    return this;
  }

  OptionBuilder setHttpClientAdapter(HttpClientAdapter httpClientAdapter) {
    _opts['httpClientAdapter'] = httpClientAdapter;
    return this;
  }

  /// Build the options map.
  Map<String, dynamic> build() => _opts;
}
