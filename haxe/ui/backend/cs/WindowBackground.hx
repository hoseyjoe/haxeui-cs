package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;

/**
 * What the window shows behind the components, white until the app sets it: a dark theme sets its
 * own, as an html5 app sets the page's background and a Heaps app the engine's clear colour.
 */
class WindowBackground {
	/** `color` is 0xRRGGBB, drawn opaque. **/
	public static function set(color:Int):Void {
		Host.SetBackground(cast(0xFF000000 | (color & 0xFFFFFF), UInt));
	}
}
