package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.Native.ICloseListener;

/**
 * A say before the window closes, as a Heaps app has with `hxd.Window.onClose` and an html5 app
 * with `beforeunload`: unsaved work can be offered for saving first.
 */
class WindowClose {
	/**
	 * Asked when the user closes the window (its close button, Alt+F4); false keeps it open, and
	 * the app can then ask the user and call `app.exit()` once it is done. Null (the default) lets
	 * every close through. `app.exit()` never asks it. One that throws is reported on stderr and
	 * the window closes.
	 */
	public static var onRequest(default, set):Null<Void->Bool>;

	static function set_onRequest(value:Null<Void->Bool>):Null<Void->Bool> {
		onRequest = value;
		Host.CloseListener = value != null ? new CloseListener(value) : null;
		return value;
	}
}

private class CloseListener implements ICloseListener {
	final fn:Void->Bool;

	public function new(fn:Void->Bool) {
		this.fn = fn;
	}

	public function OnCloseRequested():Bool {
		return fn();
	}
}
