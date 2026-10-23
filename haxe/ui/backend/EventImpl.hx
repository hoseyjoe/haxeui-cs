package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native.NativeEvents;
import haxe.ui.events.UIEvent;

@:allow(haxe.ui.backend.cs.InputListener)
class EventImpl extends EventBase {
    /** The Avalonia event this came from, if any. **/
    @:noCompletion private var _originalEvent:Dynamic;

    public override function cancel() {
        if (_originalEvent != null) {
            NativeEvents.Cancel(_originalEvent);
        }
    }

    @:noCompletion private override function postClone(event:UIEvent) {
        event._originalEvent = this._originalEvent;
    }
}
