package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native;

class ScreenImpl extends ScreenBase {
    public function new() {
    }

    private override function get_width():Float {
        return Host.ClientWidth;
    }

    private override function get_height():Float {
        return Host.ClientHeight;
    }
}
