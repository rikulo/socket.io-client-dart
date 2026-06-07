// Copyright (C) 2026 Potix Corporation. All Rights Reserved
// History: 2026-06-07
// Author: jumperchen<jumperchen@potix.com>

import 'package:web_socket/web_socket.dart' as ws;

import 'default_ws_connector_web.dart'
    if (dart.library.io) 'default_ws_connector_io.dart' as impl;

/// The connector used by [WebSocketTransport] when no custom
/// `webSocketConnector` is configured.
///
/// On native platforms it forwards [headers] (from `setExtraHeaders`) to the
/// handshake; on the web custom headers are unsupported by the browser and are
/// ignored. See [default_ws_connector_io] and [default_ws_connector_web].
Future<ws.WebSocket> connectWebSocket(Uri uri,
        {Iterable<String>? protocols, Map<String, String>? headers}) =>
    impl.connectWebSocket(uri, protocols: protocols, headers: headers);
