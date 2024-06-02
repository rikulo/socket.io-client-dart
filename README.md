# socket.io-client-dart

Port of awesome JavaScript Node.js library - [Socket.io-client v2._ ~ v4._](https://github.com/socketio/socket.io-client) - in Dart

## Version info

| socket.io-client-dart | Socket.io Server  |
| --------------------- | ----------------- |
| `v0.9.*` ~ `v1.*`     | `v2.*`            |
| `v2.*`                | `v3.*` ~ `v4.6.*` |
| `v3.*`                | `v4.7.* ~ v4.*`   |

## Usage

### Dart Server

```dart
import 'package:socket_io/socket_io.dart';

main() {
  // Dart server
  var io = Server();
  var nsp = io.of('/some');
  nsp.on('connection', (client) {
    print('connection /some');
    client.on('msg', (data) {
      print('data from /some => $data');
      client.emit('fromServer', "ok 2");
    });
  });
  io.on('connection', (client) {
    print('connection default namespace');
    client.on('msg', (data) {
      print('data from default => $data');
      client.emit('fromServer', "ok");
    });
  });
  io.listen(3000);
}
```

### Dart Client

```dart

import 'package:socket_io_client/socket_io_client.dart' as IO;

main() {
  // Dart client
  IO.Socket socket = IO.io('http://localhost:3000');
  socket.onConnect((_) {
    print('connect');
    socket.emit('msg', 'test');
  });
  socket.on('event', (data) => print(data));
  socket.onDisconnect((_) => print('disconnect'));
  socket.on('fromServer', (_) => print(_));
}
```

### Connect manually

To connect the socket manually, set the option `autoConnect: false` and call `.connect()`.

For example,

<pre>
Socket socket = io('http://localhost:3000',
    OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Dart VM
      .<b>disableAutoConnect()</b>  // disable auto-connection
      .setExtraHeaders({'foo': 'bar'}) // optional
      .build()
  );
<b>socket.connect();</b>
</pre>

Note that `.connect()` should not be called if `autoConnect: true`
(by default, it's enabled to true), as this will cause all event handlers to get registered/fired twice. See [Issue #33](https://github.com/rikulo/socket.io-client-dart/issues/33).

### Update the extra headers

```dart
Socket socket = ... // Create socket.
socket.io.options['extraHeaders'] = {'foo': 'bar'}; // Update the extra headers.
socket.io..disconnect()..connect(); // Reconnect the socket manually.
```

### Emit with acknowledgement

```dart
Socket socket = ... // Create socket.
socket.onConnect((_) {
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

```dart
const List EVENTS = [
  'connect',
  'connect_error',
  'disconnect',
  'error',
  'reconnect',
  'reconnect_attempt',
  'reconnect_failed',
  'reconnect_error',
  'ping',
  'pong'
];

// Replace 'onConnect' with any of the above events.
socket.onConnect((_) {
    print('connect');
});
```

### Acknowledge with the socket server that an event has been received

```dart
socket.on('eventName', (data) {
    final dataList = data as List;
    final ack = dataList.last as Function;
    ack(null);
});
```

## Usage (Flutter)

In Flutter env. not (Flutter Web env.) it only works with `dart:io` websocket,
not with `dart:html` websocket or Ajax (XHR), so in this case
you have to add `setTransports(['websocket'])` when creates the socket instance.

For example,

```dart
IO.Socket socket = IO.io('http://localhost:3000',
  OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Dart VM
      .setExtraHeaders({'foo': 'bar'}) // optional
      .build());
```

## Usage with stream and StreamBuilder in Flutter

```dart
import 'dart:async';


// STEP1:  Stream setup
class StreamSocket{
  final _socketResponse= StreamController<String>();

  void Function(String) get addResponse => _socketResponse.sink.add;

  Stream<String> get getResponse => _socketResponse.stream;

  void dispose(){
    _socketResponse.close();
  }
}

StreamSocket streamSocket =StreamSocket();

//STEP2: Add this function in main function in main.dart file and add incoming data to the stream
void connectAndListen(){
  IO.Socket socket = IO.io('http://localhost:3000',
      OptionBuilder()
       .setTransports(['websocket']).build());

    socket.onConnect((_) {
     print('connect');
     socket.emit('msg', 'test');
    });

    //When an event received from server, data is added to the stream
    socket.on('event', (data) => streamSocket.addResponse);
    socket.onDisconnect((_) => print('disconnect'));

}

//Step3: Build widgets with StreamBuilder

class BuildWithSocketStream extends StatelessWidget {
  const BuildWithSocketStream({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: StreamBuilder(
        stream: streamSocket.getResponse ,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot){
          return Container(
            child: snapshot.data,
          );
        },
      ),
    );
  }
}

```

## Important Notice: Handling Socket Cache and subsequent lookups

There is a design decision in the baseline IO lookup command related to the caching of socket instances.

### Lookup protocol

**We reuse the existing instance based on same scheme/port/host.**

It is important to make clear that both `dispose()` and `destroy()` do NOT remove a host from the cache of known connections. This can cause attempted
subsequent connections to ignore certain parts of your configuration if not handled correctly. You must handle this by using the options
available in the OptionBuilder _during the first creation_ of the instance.

### Examples

In the following example, there is a userId and username set as extra headers for this connection.
If you were to try and create the same connection with updated values, if the host is the same, the extra headers will not be updated and the old
connection would be returned.

```dart
_socket = io.io(
        host,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({'id': userId, 'name': username})
            .disableAutoConnect()
            .enableReconnection()
            .build());
```

In order to prevent this, depending on your application's needs, you can either use `enableForceNew()` or `disableMultiplex()` to the
option builder. These options would modify all connections using the same host, so be aware and plan accordingly.

An additional option, if it fits your use case, would be to follow the usage mentioned above in [Update the extra headers](#update-the-extra-headers).
By updating the extra headers outside of the building of the options, you can guarantee that your connections will have the values you are expecting.

## Troubleshooting

### Cannot connect "https" server or self-signed certificate server

- Refer to <https://github.com/dart-lang/sdk/issues/34284> issue.
  The workaround is to use the following code provided by [@lehno](https://github.com/lehno) on [#84](https://github.com/rikulo/socket.io-client-dart/issues/84)

```dart
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(MyApp());
}
```

### Memory leak issues in iOS when closing socket

- Refer to <https://github.com/rikulo/socket.io-client-dart/issues/108> issue.
  Please use `socket.dispose()` instead of `socket.close()` or `socket.disconnect()` to solve the memory leak issue on iOS.

### Connect_error on MacOS with SocketException: Connection failed

- Refer to <https://github.com/flutter/flutter/issues/47606#issuecomment-568522318> issue.

By adding the following key into the to file `*.entitlements` under directory `macos/Runner/`

```xml
<key>com.apple.security.network.client</key>
<true/>
```

For more details, please take a look at <https://flutter.dev/desktop#setting-up-entitlements>

### Can't connect socket server on Flutter with Insecure HTTP connection

- Refer to <https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android>

The HTTP connections are disabled by default on iOS and Android, so here is a workaround to this issue,
which mentioned on [stack overflow](https://stackoverflow.com/a/65730723)

## Notes to Contributors

### Fork socket.io-client-dart

If you'd like to contribute back to the core, you can [fork this repository](https://help.github.com/articles/fork-a-repo) and send us a pull request, when it is ready.

If you are new to Git or GitHub, please read [this guide](https://help.github.com/) first.

Contribution of all kinds is welcome. Please read [Contributing.md](https://github.com/rikulo/socket.io-client-dart/blob/master/contributing.md) in this repository.

## Who Uses

- [Quire](https://quire.io) - a simple, collaborative, multi-level task management tool.
- [KEIKAI](https://keikai.io/) - a web spreadsheet for Big Data.

## Socket.io Dart Server

- [socket.io-dart](https://github.com/rikulo/socket.io-dart)

## Contributors

<a href="https://github.com/rikulo/socket.io-client-dart/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=rikulo/socket.io-client-dart" />
</a>
