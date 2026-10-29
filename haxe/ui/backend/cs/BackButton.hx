package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.Native.IBackListener;

/**
 * Android's back (the button, or the edge swipe) for the app to handle: close what is on top,
 * and only leave the app when nothing was. The same shape as heaps-android's `BackButton`.
 *
 *   BackButton.addListener(() -> {
 *       if (!menuOpen) return false;   // not mine: pass it on
 *       closeMenu();
 *       return true;                   // handled: back stops here
 *   });
 *
 * Listeners are asked newest first (the last thing opened is usually on top), and the first to
 * return true ends it. Back that none takes sends the app to the background, as Android's own back
 * does, without finishing it. On the desktop back never arrives and registering is harmless.
 */
class BackButton {
	static var listeners:Array<Void->Bool> = [];

	/** Register `fn`; return true from it when it handled back. **/
	public static function addListener(fn:Void->Bool):Void {
		listeners.push(fn);
		if (Host.BackListener == null) Host.BackListener = new Listener();
	}

	public static function removeListener(fn:Void->Bool):Void {
		listeners.remove(fn);
	}

	public static function clearListeners():Void {
		listeners = [];
	}

	/** Back was pressed: the newest listener first. True when one took it. **/
	static function press():Bool {
		// A copy, so a listener can remove itself (or add another) while handling back.
		var all = listeners.copy();
		var i = all.length;
		while (i-- > 0) if (all[i]()) return true;
		return false;
	}
}

private class Listener implements IBackListener {
	public function new() {
	}

	public function OnBack():Bool {
		return @:privateAccess BackButton.press();
	}
}
