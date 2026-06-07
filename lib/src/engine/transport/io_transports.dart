// Copyright (C) 2019 Potix Corporation. All Rights Reserved
// History: 2019-01-21 12:15
// Author: jumperchen<jumperchen@potix.com>
import 'package:socket_io_client/src/engine/transport.dart';
import 'package:socket_io_client/src/engine/transport/websocket_transport.dart';

class Transports {
  static List<String> upgradesTo(String from) {
    if ('polling' == from) {
      return ['websocket'];
    }
    return [];
  }

  static Transport newInstance(String name, dynamic options) {
    // Native only supports websocket
    return WebSocketTransport(options);
  }
}
