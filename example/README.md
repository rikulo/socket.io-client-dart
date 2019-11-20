# socket.io-client-dart example

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