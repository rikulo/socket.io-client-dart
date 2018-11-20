import 'package:socket_io_common/src/util/event_emitter.dart';

/**
 * on.dart
 *
 * Purpose:
 *
 * Description:
 *
 * History:
 *   26/04/2017, Created by jumperchen
 *
 * Copyright (C) 2017 Potix Corporation. All Rights Reserved.
 */

/**
 * Helper for subscriptions.
 *
 * @param {Object|EventEmitter} obj with `Emitter` mixin or `EventEmitter`
 * @param {String} event name
 * @param {Function} callback
 * @api public
 */
on(EventEmitter obj, String ev, EventHandler fn) {
  obj.on(ev, fn);
  return new Destroyable(() => obj.off(ev, fn));
}

class Destroyable {
  Function callback;
  Destroyable(this.callback);
  destroy() => callback();
}
