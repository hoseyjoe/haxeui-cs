package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;

/** A photograph of the app's window as it stands, desktop or headless. **/
class WindowCapture {
	/** Writes the window's content to `path` as PNG; false when there is no window yet. **/
	public static function save(path:String):Bool {
		return Host.CaptureWindow(path);
	}
}
