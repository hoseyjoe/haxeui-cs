package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.Native.IPauseListener;

/**
 * The app's life beyond its window. On Android an app in the background can be ended at any time
 * without a word, so whatever must survive (a reading position) is saved when it goes there.
 */
class AppLifecycle {
	/**
	 * Called when the app goes to the background (Android's onPause: Home, another app, the screen
	 * turning off). Null (the default) does nothing. Never called on the desktop, where
	 * `WindowClose.onRequest` is the last word. One that throws is reported on stderr and ignored.
	 */
	public static var onPause(default, set):Null<Void->Void>;

	static function set_onPause(value:Null<Void->Void>):Null<Void->Void> {
		onPause = value;
		Host.PauseListener = value != null ? new PauseListener(value) : null;
		return value;
	}
}

private class PauseListener implements IPauseListener {
	final fn:Void->Void;

	public function new(fn:Void->Void) {
		this.fn = fn;
	}

	public function OnPause():Void {
		fn();
	}
}
