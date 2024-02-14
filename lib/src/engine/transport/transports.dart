/// Copyright (C) 2017 Potix Corporation. All Rights Reserved
/// History: 2017-04-26 12:27
/// Author: jumperchen<jumperchen@potix.com>
import 'package:socket_io_client/src/engine/transport.dart';
import 'package:socket_io_client/src/engine/transport/polling_transport.dart';
import 'package:socket_io_client/src/engine/transport/websocket_transport.dart';

class Transports {
  static List<String> upgradesTo(String from) {
    if ('polling' == from) {
      return ['websocket'];
    }
    return [];
  }

  static Transport newInstance(String name, options) {
    if ('websocket' == name) {
      return WebSocketTransport(options);
    } else if ('polling' == name) {
      return PollingTransport(options);
    } else {
      throw UnsupportedError('Unknown transport $name');
    }
  }
}
