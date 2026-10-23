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

	// Pointer input, in window coordinates. Buttons: 0 left, 1 middle, 2 right.

	public static function mouseMove(x:Float, y:Float):Void {
		HeadlessDriver.MouseMove(x, y);
	}

	public static function mouseDown(x:Float, y:Float, button:Int = 0):Void {
		HeadlessDriver.MouseDown(x, y, button);
	}

	public static function mouseUp(x:Float, y:Float, button:Int = 0):Void {
		HeadlessDriver.MouseUp(x, y, button);
	}

	/** Moves there, presses and releases the left button, and lets the effects run. **/
	public static function click(x:Float, y:Float):Void {
		mouseMove(x, y);
		mouseDown(x, y);
		pump();
		mouseUp(x, y);
		pump();
	}

	/** deltaY > 0 scrolls up, deltaY < 0 down. **/
	public static function wheel(x:Float, y:Float, deltaY:Float):Void {
		HeadlessDriver.Wheel(x, y, deltaY);
	}

	/** Presses and releases a key named as Avalonia's Key enum: "Enter", "Tab", "A". **/
	public static function key(name:String, ctrl:Bool = false, shift:Bool = false):Void {
		HeadlessDriver.KeyStroke(name, ctrl, shift);
	}

	/** Text arriving as typed input, into whatever has keyboard focus. **/
	public static function type(text:String):Void {
		HeadlessDriver.TypeText(text);
	}

	public static function centerOf(c:haxe.ui.core.Component):{x:Float, y:Float} {
		return {x: c.screenLeft + c.width / 2, y: c.screenTop + c.height / 2};
	}

	public static function clickComponent(c:haxe.ui.core.Component):Void {
		var p = centerOf(c);
		click(p.x, p.y);
	}
}
#end
