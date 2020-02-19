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
    

    
### Connect manually
To connect the socket manually, set the option `autoConnect: false` and call `.connect()`.

For example,
<pre>
Socket socket = io('http://localhost:3000', &lt;String, dynamic>{
    'transports': ['websocket'],
    <b>'autoConnect': false</b>,
    'extraHeaders': {'foo': 'bar'} // optional
  });
<b>socket.connect();</b>
</pre>

Note that `.connect()` should not be called if `autoConnect: true`, as this will cause all event handlers to get registered/fired twice. See [Issue #33](https://github.com/rikulo/socket.io-client-dart/issues/33).

### Update the extra headers
```
Socket socket = ... // Create socket.
socket.io.options['extraHeaders'] = {'foo': 'bar'}; // Update the extra headers.
socket.io..disconnect()..connect(); // Reconnect the socket manually.
```

### Emit with acknowledgement
```
Socket socket = ... // Create socket.
socket.on('connect', (_) {
    print('connect');
    socket.emitWithAck('msg', 'init', ack: (data) {
        print('ack $data') ;
        if (data != null) {
          print('from server $data');
        } else {
          print("Null") ;
        }
    });
});
```

### Socket connection events
These events can be listened on.
```
const List EVENTS = [
  'connect',
  'connect_error',
  'connect_timeout',
  'connecting',
  'disconnect',
  'error',
  'reconnect',
  'reconnect_attempt',
  'reconnect_failed',
  'reconnect_error',
  'reconnecting',
  'ping',
  'pong'
];

// Replace 'connect' with any of the above events.
socket.on('connect', (_) {
    print('connect');
}
```

### Acknowledge with the socket server that an event has been received.
```
socket.on('eventName', (data) {
    final dataList = data as List;
    final ack = dataList.last as Function;
    ack(null);
});
```
    
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