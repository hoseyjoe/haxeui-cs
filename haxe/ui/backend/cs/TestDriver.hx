package haxe.ui.backend.cs;

#if haxeui_cs_headless
import haxe.ui.backend.cs.native.Native.HeadlessDriver;

/**
 * Test support for apps built with `-D haxeui_cs_headless`: runs the host's
 * queued work so a test can see its effects synchronously.
 */
class TestDriver {
	public static function pump(frames:Int = 1):Void {
		HeadlessDriver.Pump(frames);
	}
}
#end
