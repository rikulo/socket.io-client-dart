// Copyright (C) 2025 Potix Corporation. All Rights Reserved
// Author: jumperchen<jumperchen@potix.com>

/// Adapter responsible for establishing the underlying WebSocket connection
/// used by the `websocket` transport.
///
/// Deprecated: implement a `WebSocketConnector` and pass it through
/// `OptionBuilder.setWebSocketConnector` instead. This interface is kept for
/// backward compatibility with 3.1.1–3.1.4 (it was unintentionally dropped in
/// 3.1.5) and will be removed in 4.0.0.
@Deprecated('Use WebSocketConnector with OptionBuilder.setWebSocketConnector '
    'instead. HttpClientAdapter will be removed in 4.0.0.')
abstract class HttpClientAdapter {
  /// Connects to [uri] and returns the established socket.
  ///
  /// The returned value may be a `dart:io` `WebSocket` (native) or a
  /// `package:web_socket` `WebSocket`; both are accepted and adapted to the
  /// unified transport.
  Future<dynamic> connect(String uri, {Map<String, dynamic>? headers});
}
