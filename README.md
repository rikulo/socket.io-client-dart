# socket.io-client-dart

Port of awesome JavaScript Node.js library - [Socket.io-client v2.0.1](https://github.com/socketio/socket.io-client) - in Dart

## Usage


    import 'package:socket_io/socket_io.dart';
    import 'package:socket_io_client/socket_io_client.dart' as IO;

    main() {
        // Dart server
        var io = new Server();
        var nsp = io.of('/some');
        nsp.on('connection', (Socket client) {
          print('connection /some');
          client.on('msg', (data) {
            print('data from /some => $data');
            client.emit('fromServer', "ok 2");
          });
        });
          io.on('connection', (Socket client) {
            print('connection default namespace');
            client.on('msg', (data) {
              print('data from default => $data');
              client.emit('fromServer', "ok");
            });
          });
          io.listen(3000);

        // Dart client
        IO.Socket socket = IO.io('http://localhost:3000');
        socket.on('connect', (_) {
         print('connect');
         socket.emit('msg', 'test');
        });
        socket.on('event', (data) => print(data));
        socket.on('disconnect', (_) => print('disconnect'));
        socket.on('fromServer', (_) => print(_));
    }
    
## Usage (Flutter)
In Flutter env. it only works with `dart:io` websocket, not with `dart:html` websocket, so in this case
you have to add `'transports': ['websocket']` when creates the socket instance.

For example,
```
IO.Socket socket = IO.io('http://localhost:3000', <String, dynamic>{
    'transports': ['websocket'],
    'extraHeaders': {'foo': 'bar'} // optional
  });
```

## Notes to Contributors

### Fork socket.io-client-dart

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.

## Who Uses

* [Quire](https://quire.io) - a simple, collaborative, multi-level task management tool.
* [KEIKAI](https://keikai.io/) - a web spreadsheet for Big Data.

## Socket.io Dart Server

* [socket.io-dart](https://github.com/rikulo/socket.io-dart)


## Contributors
* Thanks [@felangel](https://github.com/felangel) for https://github.com/rikulo/socket.io-client-dart/issues/7
* Thanks [@Oskang09](https://github.com/Oskang09) for https://github.com/rikulo/socket.io-client-dart/issues/21
* Thanks [@bruce3x](https://github.com/bruce3x) for https://github.com/rikulo/socket.io-client-dart/issues/25
* Thanks [@Kavantix](https://github.com/Kavantix) for https://github.com/rikulo/socket.io-client-dart/issues/26