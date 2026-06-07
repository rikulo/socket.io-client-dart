// Copyright (C) 2026 Potix Corporation. All Rights Reserved
// History: 2026-06-07
// Author: jumperchen<jumperchen@potix.com>

import 'dart:io' as io;

import 'package:web_socket/io_web_socket.dart' show IOWebSocket;
import 'package:web_socket/web_socket.dart' as ws;

/// Default WebSocket connector for native (`dart:io`) platforms.
///
/// Forwards [headers] (populated from `setExtraHeaders`) to the underlying
/// `dart:io` WebSocket handshake, so header/cookie based authentication keeps
/// working without the caller having to supply a custom `webSocketConnector`.
/// This restores the behaviour that existed before the migration to
/// package:web_socket.
Future<ws.WebSocket> connectWebSocket(Uri uri,
    {Iterable<String>? protocols, Map<String, String>? headers}) async {
  // The socket is handed off to IOWebSocket and closed via Transport.doClose.
  // ignore: close_sinks
  final io.WebSocket socket;
  try {
    socket = await io.WebSocket.connect(
      uri.toString(),
      protocols: protocols,
      headers: headers,
    );
  } on io.WebSocketException catch (e) {
    throw ws.WebSocketException(e.message);
  }
  return IOWebSocket.fromWebSocket(socket);
}
