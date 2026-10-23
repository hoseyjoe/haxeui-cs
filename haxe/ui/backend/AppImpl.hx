package haxe.ui.backend;

import haxe.ui.backend.cs.Callbacks;
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
        // Toolkit.init has already handed the app's options to the screen.
        var options = haxe.ui.core.Screen.instance.options;
        var title = (options != null && options.title != null) ? options.title : "";
        #if haxeui_cs_headless
        var width = (options != null && options.width != null) ? options.width : 800;
        var height = (options != null && options.height != null) ? options.height : 600;
        Host.Title = title;
        Host.StartHeadless(new HostListener(onReady, onEnd, false), width, height);
        #else
        var width = (options != null && options.width != null) ? options.width : 1024;
        var height = (options != null && options.height != null) ? options.height : 768;
        Host.RunDesktop(new HostListener(onReady, onEnd, true), title, width, height);
        #end
    }
}

private class HostListener implements IHostListener {
    /** How often the desktop drives Haxe's own main-thread events (haxe.Timer, haxe.MainLoop). **/
    static inline var HAXE_EVENTS_INTERVAL_MS = 10;

    var onReady:Void->Void;
    var onEnd:Void->Void;
    var pumpHaxeEvents:Bool;

    public function new(onReady:Void->Void, onEnd:Void->Void, pumpHaxeEvents:Bool) {
        this.onReady = onReady;
        this.onEnd = onEnd;
        this.pumpHaxeEvents = pumpHaxeEvents;
    }

    public function OnReady():Void {
        // Avalonia's loop owns the main thread, so Haxe's event loop never gets
        // a turn unless the dispatcher gives it one.
        if (pumpHaxeEvents) {
            Host.StartTimer(HAXE_EVENTS_INTERVAL_MS, Callbacks.callback(() -> sys.thread.Thread.current().events.progress()));
        }
        onReady();
    }

    public function OnResize(width:Float, height:Float):Void {
        @:privateAccess haxe.ui.core.Screen.instance.onHostResize();
    }

    public function OnClosed():Void {
        var code = 0;
        if (onEnd != null) {
            try {
                onEnd();
            } catch (e:Dynamic) {
                // reported, and still the end of the app: never a hang, never a quiet 0
                Sys.stderr().writeString('haxeui-cs: onEnd threw: $e\n');
                code = 1;
            }
        }
        // After main() returns, Haxe waits on its event loop for as long as any
        // repeating haxe.Timer exists; a closed window is the end of the app.
        Host.Exit(code);
    }
}
