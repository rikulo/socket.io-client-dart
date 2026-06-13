// Copyright (C) 2025 Potix Corporation. All Rights Reserved
// Author: jumperchen<jumperchen@potix.com>

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:web_socket/web_socket.dart' as ws;

import 'http_client_adapter.dart';

import 'legacy_adapter_connector_web.dart'
    if (dart.library.io) 'legacy_adapter_connector_io.dart' as impl;

/// Bridges the deprecated [HttpClientAdapter] to the package:web_socket based
/// WebSocket transport.
///
/// It invokes [HttpClientAdapter.connect] and adapts whatever it returns
/// (a `dart:io` `WebSocket` or a [ws.WebSocket]) into a [ws.WebSocket] so the
/// unified transport can use it. Used to keep `setHttpClientAdapter` working
/// after the migration to package:web_socket.
Future<ws.WebSocket> connectViaAdapter(HttpClientAdapter adapter, Uri uri,
        {Iterable<String>? protocols, Map<String, String>? headers}) =>
    impl.connectViaAdapter(adapter, uri,
        protocols: protocols, headers: headers);
