// Copyright (C) 2025 Potix Corporation. All Rights Reserved
// Author: jumperchen<jumperchen@potix.com>

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io' as io;

import 'package:web_socket/io_web_socket.dart' show IOWebSocket;
import 'package:web_socket/web_socket.dart' as ws;

import 'http_client_adapter.dart';

/// Native (`dart:io`) bridge for the deprecated [HttpClientAdapter].
///
/// Wraps a `dart:io` `WebSocket` returned by the legacy adapter into a
/// [ws.WebSocket] via [IOWebSocket.fromWebSocket]. If the adapter already
/// returns a [ws.WebSocket], it is forwarded unchanged.
Future<ws.WebSocket> connectViaAdapter(HttpClientAdapter adapter, Uri uri,
    {Iterable<String>? protocols, Map<String, String>? headers}) async {
  final raw = await adapter.connect(uri.toString(), headers: headers);
  if (raw is ws.WebSocket) return raw;
  if (raw is io.WebSocket) return IOWebSocket.fromWebSocket(raw);
  throw ws.WebSocketException(
      'HttpClientAdapter.connect must return a dart:io WebSocket or a '
      'package:web_socket WebSocket, but returned ${raw.runtimeType}.');
}
