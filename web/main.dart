import 'dart:async';
/**
 * main.dart
 *
 * Purpose:
 *
 * Description:
 *
 * History:
 *   26/07/2017, Created by jumperchen
 *
 * Copyright (C) 2017 Potix Corporation. All Rights Reserved.
 */
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:socket_io_common/socket_io_common.dart';

void main() {
  var socket = io.io(
      'http://localhost:3000',
      io.OptionBuilder()
          .setTransports(['polling'])
          .setParser(io.ParserOptions(
              encoder: () => MyEncoder(), decoder: () => MyDecoder()))
          // .disableAutoConnect()
          .build());

  // socket.connect();

  socket.onConnect((_) {
    socket.emit('toServer', 'init');

    var count = 0;
    Timer.periodic(const Duration(seconds: 1), (Timer countDownTimer) {
      socket.emit('toServer', count++);
    });
  });

  socket.on('event', (data) => print(data));
  socket.on('disconnect', (_) => print('disconnect'));
  socket.on('fromServer', (data) => print(data));
}

class MyEncoder extends Encoder {
  @override
  List<Object?> encode(Object? obj) {
    print('MyEncoder: $obj');
    return super.encode(obj);
  }
}

class MyDecoder extends Decoder {
  @override
  add(obj) {
    print('MyDecoder: $obj');
    return super.add(obj);
  }
}
