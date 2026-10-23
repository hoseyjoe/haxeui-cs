package haxe.ui.backend.cs;

#if haxeui_cs_headless
import haxe.ui.backend.cs.native.Native.HeadlessDriver;
import haxe.ui.validation.ValidationManager;

/**
 * Test support for apps built with `-D haxeui_cs_headless`: runs queued work
 * so a test can see its effects synchronously, resizes the window and reads
 * back rendered pixels.
 */
class TestDriver {
	/** Runs Haxe's queued events, HaxeUI's validation and Avalonia's jobs and a render, `frames` times. **/
	public static function pump(frames:Int = 1):Void {
		for (i in 0...frames) {
			sys.thread.Thread.current().events.progress();
			var passes = 0;
			while (ValidationManager.instance.isPending && passes++ < 100) {
				ValidationManager.instance.process();
			}
			HeadlessDriver.Pump(1);
		}
	}

	public static function resizeWindow(width:Int, height:Int):Void {
		HeadlessDriver.ResizeWindow(width, height);
	}

	public static function capture(path:String):Void {
		HeadlessDriver.Capture(path);
	}

	/** ARGB of the rendered pixel at (x, y), in window coordinates. **/
	public static function pixel(x:Int, y:Int):Int {
		return HeadlessDriver.PixelAt(x, y);
	}
}
#end
