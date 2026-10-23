package haxe.ui.backend;

import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/** A repeating timer on Avalonia's dispatcher, so it ticks on the UI thread with nothing else pumping. **/
class TimerImpl {
    private var _handle:Dynamic;

    public function new(delay:Int, callback:Void->Void) {
        _handle = Host.StartTimer(delay, Callbacks.callback(callback));
    }

    public function stop() {
        if (_handle != null) {
            Host.StopTimer(_handle);
            _handle = null;
        }
    }
}
