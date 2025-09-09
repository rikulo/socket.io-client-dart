## 3.1.3

**New Feature:**

- Added withCredentials as an option

## 3.1.2

**Bug fix:**

- [#379](https://github.com/rikulo/socket.io-client-dart/issues/379#issuecomment-2407013081) Dynamic call with too many positional arguments. Expected: 2 Actual: 3

## 3.1.1

**New Feature:**

- [#416](https://github.com/rikulo/socket.io-client-dart/pull/416) Add Support for Custom HttpClient Configuration

## 3.1.0+2

**Bug fix:**

- [websocket connection cannot be established in WASM mode](https://github.com/rikulo/socket.io-client-dart/pull/412#issuecomment-2756685758)

## 3.1.0+1

**Bug fix:**

- [websocket connection cannot be established](https://github.com/rikulo/socket.io-client-dart/pull/412#issuecomment-2756531708)

## 3.1.0

**Bug fix:**

- [#392](https://github.com/rikulo/socket.io-client-dart/issues/392) [Flutter WASM] No transports available
- [#404](https://github.com/rikulo/socket.io-client-dart/issues/404) Flutter web socket connection problem on wasm

## 3.0.2

**Bug fix:**

- [#399](https://github.com/rikulo/socket.io-client-dart/issues/399) [Issue] Fixes timestamp param

## 3.0.1

**Bug fix:**

- [#398](https://github.com/rikulo/socket.io-client-dart/issues/398) [Issue] Unhandled Exception: type 'String' is not a subtype of type 'Iterable<dynamic>' on Server Acknowledgement

## 3.0.0

**Bug fix:**

- Upgrade to use socket_io_common 3.0.0

## 3.0.0-beta.4

**Bug fix:**

- [#394](https://github.com/rikulo/socket.io-client-dart/issues/394) Incorrect argument matching in notifyOutgoingListeners

## 3.0.0-beta.3

**Bug fix:**

- [#393](https://github.com/rikulo/socket.io-client-dart/issues/393) Bug: type 'Null' is not a subtype of type 'bool'

## 3.0.0-beta.2

**Bug fix:**

- [#373](https://github.com/rikulo/socket.io-client-dart/issues/373) hot restart error - Unhandled Exception: type 'Null' is not a subtype of type 'bool'

## 3.0.0-beta.1

**Bug fix:**

- [#367](https://github.com/rikulo/socket.io-client-dart/issues/367) Error on dispose

## 3.0.0-beta.0

**New Feature:**

- Update codebase for compatibility with Socket.IO v4.7.4 and migrate to Dart version 3
- [#55](https://github.com/rikulo/socket.io-client-dart/issues/55) how to custom parser
- [#322](https://github.com/rikulo/socket.io-client-dart/pull/322) added emitWithAckAsync
- [#334](https://github.com/rikulo/socket.io-client-dart/pull/334) Socket.on... returns disposer function
- [#343](https://github.com/rikulo/socket.io-client-dart/issues/343) Empty query map in OptionsBuilder throws RangeError
- [#353](https://github.com/rikulo/socket.io-client-dart/issues/353) Add timeout on emit and emitWithAck

**Bug fix:**

- [#360](https://github.com/rikulo/socket.io-client-dart/pull/360) Library is not compatible with latest version on socket.io 4.7.4

## 2.0.3+1

Fix dart analyzing issues

## 2.0.3

**New Feature:**

- [#338](https://github.com/rikulo/socket.io-client-dart/pull/338) feat: implement connection state recovery

## 2.0.2

**Bug fix:**

- [#330](https://github.com/rikulo/socket.io-client-dart/issues/330) Client throws error when buffer is received

## 2.0.1

**New Feature:**

- [#310](https://github.com/rikulo/socket.io-client-dart/pull/310) Add setAuthFn for OptionBuilder

**Bug fix:**

- [#287](https://github.com/rikulo/socket.io-client-dart/issues/287) reconnecting event is not triggered

## 2.0.0

**New Feature:**

- [#237](https://github.com/rikulo/socket.io-client-dart/pull/237) Allow sending an ack with multiple data items (making it consistent with emit)

## 1.0.2

**New Feature:**

- [#237](https://github.com/rikulo/socket.io-client-dart/pull/237) Allow sending an ack with multiple data items (making it consistent with emit)

## 1.0.1

**Bug fix:**

- [#188](https://github.com/rikulo/socket.io-client-dart/pull/188) Fixbug for Backoff when many attempts: "UnsupportedError: Unsupported operation: Infinity or NaN toInt"

## 2.0.0-beta.4-nullsafety.0

**New Feature:**

- [#177](https://github.com/rikulo/socket.io-client-dart/pull/177) Send credentials with the auth option

**Bug fix:**

- [#172](https://github.com/rikulo/socket.io-client-dart/issues/172) socket id's not synced

## 2.0.0-beta.3-nullsafety.0

**New Feature:**

- [#163](https://github.com/rikulo/socket.io-client-dart/issues/163) Null safety support for 2.0.0-beta

## 2.0.0-beta.3

**Bug fix:**

- [#150](https://github.com/rikulo/socket.io-client-dart/issues/150) Problem with setQuery in socket io version 3.0

## 2.0.0-beta.2

**Bug fix:**

- [#140](https://github.com/rikulo/socket.io-client-dart/issues/140) getting Error on emitWithAck() in v2 beta

## 2.0.0-beta.1

**New Feature:**

- [#130](https://github.com/rikulo/socket.io-client-dart/issues/130) Cannot connect to socket.io V3
- [#106](https://github.com/rikulo/socket.io-client-dart/issues/106) Can we combine emitWithBinary to emit?

## 1.0.0

- [#172](https://github.com/rikulo/socket.io-client-dart/issues/172) socket id's not synced

## 2.0.0-beta.3-nullsafety.0

**New Feature:**

- [#163](https://github.com/rikulo/socket.io-client-dart/issues/163) Null safety support for 2.0.0-beta

## 2.0.0-beta.3

**Bug fix:**

- [#150](https://github.com/rikulo/socket.io-client-dart/issues/150) Problem with setQuery in socket io version 3.0

## 2.0.0-beta.2

**Bug fix:**

- [#140](https://github.com/rikulo/socket.io-client-dart/issues/140) getting Error on emitWithAck() in v2 beta

## 2.0.0-beta.1

**New Feature:**

- [#130](https://github.com/rikulo/socket.io-client-dart/issues/130) Cannot connect to socket.io V3
- [#106](https://github.com/rikulo/socket.io-client-dart/issues/106) Can we combine emitWithBinary to emit?

**New Feature:**

- [#132](https://github.com/rikulo/socket.io-client-dart/issues/132) Migrating to null safety for Dart

## 0.9.12

**New Feature:**

- [#46](https://github.com/rikulo/socket.io-client-dart/issues/46) Make this library more "Darty"

## 0.9.11

**New Feature:**

- [#108](https://github.com/rikulo/socket.io-client-dart/issues/108) Need dispose method for clearing resources

## 0.9.10+2

- Fix dart analyzer warning for formatting issues.

## 0.9.10+1

- Fix dart analyzer warning.

## 0.9.10

**Bug fix:**

- [#72](https://github.com/rikulo/socket.io-client-dart/issues/72) Can't send Iterable as one packet

## 0.9.9

**Bug fix:**

- [#67](https://github.com/rikulo/socket.io-client-dart/issues/67) Retry connection backoff after 54 tries reconnections every 0 second

## 0.9.8

**Bug fix:**

- [#33](https://github.com/rikulo/socket.io-client-dart/issues/33) socket.on('receiveMessage',(data)=>print("data")) called twice

## 0.9.7+2

**New Feature:**

- [#48](https://github.com/rikulo/socket.io-client-dart/issues/48) add links to github repo in pubspec.yaml

## 0.9.7+1

**New Feature:**

- [#38](https://github.com/rikulo/socket.io-client-dart/issues/38) Improve pub.dev score

## 0.9.6+3

**Bug fix:**

- [#42](https://github.com/rikulo/socket.io-client-dart/issues/42) Error when using emitWithAck

## 0.9.5

**New Feature:**

- [#34](https://github.com/rikulo/socket.io-client-dart/issues/34) Add support for extraHeaders

**Bug fix:**

- [#39](https://github.com/rikulo/socket.io-client-dart/issues/39) The factor of Backoff with 54 retries causes an overflow
