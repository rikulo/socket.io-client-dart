// Copyright (C) 2025 Potix Corporation. All Rights Reserved
// Author: jumperchen<jumperchen@potix.com>

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:web_socket/web_socket.dart' as ws;

import 'http_client_adapter.dart';

/// Web (and any non-`dart:io`) bridge for the deprecated [HttpClientAdapter].
///
/// Browsers cannot use a custom `dart:io` `HttpClient`, so a legacy adapter is
/// only honoured when it returns a [ws.WebSocket]; otherwise the default
/// browser WebSocket connection is established (custom headers are ignored, as
/// browsers forbid them on the WebSocket handshake).
Future<ws.WebSocket> connectViaAdapter(HttpClientAdapter adapter, Uri uri,
    {Iterable<String>? protocols, Map<String, String>? headers}) async {
  final raw = await adapter.connect(uri.toString(), headers: headers);
  if (raw is ws.WebSocket) return raw;
  return ws.WebSocket.connect(uri, protocols: protocols);
}
