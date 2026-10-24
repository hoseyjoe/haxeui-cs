package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;

/**
 * A cursor for the whole window, as html5 sets one on the document body: core holds the
 * resize cursor this way while a splitter is dragged, wherever the pointer goes.
 */
class ScreenCursor {
	public static function set(css:String):Void {
		Host.SetScreenCursor(css);
	}

	public static function clear():Void {
		Host.SetScreenCursor(null);
	}
}
