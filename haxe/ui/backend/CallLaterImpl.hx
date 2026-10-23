package haxe.ui.backend;

import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/** Runs `fn` with the next frame (requestAnimationFrame, as html5 does): never re-entrantly, never as a busy loop. **/
class CallLaterImpl {
    public function new(fn:Void->Void) {
        Host.NextFrame(Callbacks.callback(fn));
    }
}
