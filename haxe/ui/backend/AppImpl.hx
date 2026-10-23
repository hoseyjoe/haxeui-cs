package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native;

/**
 * Starts the Avalonia host and hands HaxeUI its `onReady` once the window
 * exists. On the desktop the host's loop runs inside `init`, so `ready()`
 * returns only when the window has closed; headless (`-D haxeui_cs_headless`)
 * it returns straight after `onReady`, and the caller drives the dispatcher.
 */
class AppImpl extends AppBase {
    public function new() {
    }

    private override function init(onReady:Void->Void, onEnd:Void->Void = null) {
        var listener = new HostListener(onReady, onEnd);
        #if haxeui_cs_headless
        Host.StartHeadless(listener, 800, 600);
        #else
        Host.RunDesktop(listener, "", 1024, 768);
        #end
    }
}

private class HostListener implements IHostListener {
    var onReady:Void->Void;
    var onEnd:Void->Void;

    public function new(onReady:Void->Void, onEnd:Void->Void) {
        this.onReady = onReady;
        this.onEnd = onEnd;
    }

    public function OnReady():Void {
        onReady();
    }

    public function OnResize(width:Float, height:Float):Void {
    }

    public function OnClosed():Void {
        if (onEnd != null) {
            onEnd();
        }
    }
}
