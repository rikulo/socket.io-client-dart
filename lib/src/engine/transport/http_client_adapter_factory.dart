import 'package:socket_io_client/src/engine/transport/http_client_adapter.dart';

import 'unknown_http_client_adapter.dart'
    if (dart.library.io) 'io_http_client_adapter.dart'
    if (dart.library.js_interop) 'html_http_client_adapter.dart';

HttpClientAdapter createPlatformHttpClientAdapter() {
  return makePlatformHttpClientAdapter();
}
