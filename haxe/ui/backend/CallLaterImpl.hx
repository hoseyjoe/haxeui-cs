package haxe.ui.backend;

import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/** Runs `fn` on a later turn of Avalonia's dispatcher, never re-entrantly. **/
class CallLaterImpl {
    public function new(fn:Void->Void) {
        Host.Post(Callbacks.callback(fn));
    }
}
