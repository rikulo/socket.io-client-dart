// Copyright (C) 2026 Potix Corporation. All Rights Reserved
// History: 2026-06-07
// Author: jumperchen<jumperchen@potix.com>

import 'package:web_socket/web_socket.dart' as ws;

/// Default WebSocket connector for the web (and any non-`dart:io`) platform.
///
/// Browsers cannot set custom headers on the WebSocket handshake (a browser
/// security restriction), so [headers] is accepted for API symmetry with the
/// native connector but is intentionally ignored.
Future<ws.WebSocket> connectWebSocket(Uri uri,
        {Iterable<String>? protocols, Map<String, String>? headers}) =>
    ws.WebSocket.connect(uri, protocols: protocols);
