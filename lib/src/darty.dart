// Copyright (C) 2020 Potix Corporation. All Rights Reserved
// History: 2020/11/27 11:47 AM
// Author: jumperchen<jumperchen@potix.com>

import 'package:socket_io_client/socket_io_client.dart';
import 'package:socket_io_common/src/util/event_emitter.dart';

/// Default event listeners for dart way API.
extension DartySocket on Socket {
  void Function() onConnect(EventHandler handler) {
    return on('connect', handler);
  }

  void Function() onConnectError(EventHandler handler) {
    return on('connect_error', handler);
  }

  void Function() onConnectTimeout(EventHandler handler) {
    return on('connect_timeout', handler);
  }

  void Function() onConnecting(EventHandler handler) {
    return on('connecting', handler);
  }

  void Function() onDisconnect(EventHandler handler) {
    return on('disconnect', handler);
  }

  void Function() onError(EventHandler handler) {
    return this.io.on('error', handler);
  }

  void Function() onReconnect(EventHandler handler) {
    return this.io.on('reconnect', handler);
  }

  void Function() onReconnectAttempt(EventHandler handler) {
    return this.io.on('reconnect_attempt', handler);
  }

  void Function() onReconnectFailed(EventHandler handler) {
    return this.io.on('reconnect_failed', handler);
  }

  void Function() onReconnectError(EventHandler handler) {
    return this.io.on('reconnect_error', handler);
  }

  void Function() onReconnecting(EventHandler handler) {
    return on('reconnecting', handler);
  }

  void Function() onPing(EventHandler handler) {
    return this.io.on('ping', handler);
  }

  void Function() onPong(EventHandler handler) {
    return on('pong', handler);
  }
}

/// Option Builder to help developer to construct an options map.
class OptionBuilder {
  final Map<String, dynamic> _opts;
  OptionBuilder() : _opts = <String, dynamic>{};
  OptionBuilder enableForceNew() {
    _opts['forceNew'] = true;
    return this;
  }

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

  OptionBuilder enableMultiplex() {
    _opts['multiplex'] = true;
    return this;
  }

  OptionBuilder disableMultiplex() {
    _opts.remove('multiplex');
    return this;
  }

  OptionBuilder setQuery(Map query) {
    _opts['query'] = query;
    return this;
  }

  OptionBuilder setPath(String path) {
    _opts['path'] = path;
    return this;
  }

  OptionBuilder enableAutoConnect() {
    _opts.remove('autoConnect');
    return this;
  }

  OptionBuilder disableAutoConnect() {
    _opts['autoConnect'] = false;
    return this;
  }

  OptionBuilder setReconnectionAttempts(num attempts) {
    _opts['reconnectionAttempts'] = attempts;
    return this;
  }

  OptionBuilder setReconnectionDelay(int delay) {
    _opts['reconnectionDelay'] = delay;
    return this;
  }

  OptionBuilder setReconnectionDelayMax(int delayMax) {
    _opts['reconnectionDelayMax'] = delayMax;
    return this;
  }

  OptionBuilder setRandomizationFactor(num factor) {
    _opts['randomizationFactor'] = factor;
    return this;
  }

  OptionBuilder setTimeout(int timeout) {
    _opts['timeout'] = timeout;
    return this;
  }

  OptionBuilder enableReconnection() {
    _opts.remove('reconnection');
    return this;
  }

  OptionBuilder disableReconnection() {
    _opts['reconnection'] = false;
    return this;
  }

  OptionBuilder setTransports(List<String> transports) {
    _opts['transports'] = transports;
    return this;
  }

  OptionBuilder setExtraHeaders(Map<String, dynamic> headers) {
    _opts['extraHeaders'] = headers;
    return this;
  }

  OptionBuilder setAuth(Map auth) {
    _opts['auth'] = auth;
    return this;
  }

  OptionBuilder setAuthFn(void Function(void Function(Map auth) callback) authFn) {
    _opts['auth'] = authFn;
    return this;
  }

  Map<String, dynamic> build() => _opts;
}
