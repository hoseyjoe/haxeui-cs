import haxe.Timer;
import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.AppDriver;
import haxe.ui.backend.cs.native.Native.FileDialogs;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.Native.IFileDialogListener;
import haxe.ui.components.Button;
import haxe.ui.components.TextField;
import haxe.ui.containers.Absolute;
import haxe.ui.core.Component;
import haxe.ui.focus.FocusManager;

/** Win32Probe.cs: the foreground window's owner, our window's extended styles, our visible windows, and the watch for one on a display. Read only. **/
@:native("DriveWindowApp.Win32Probe")
extern class Win32Probe {
	static function ForegroundIsOurs():Int;
	static function ExStyleOfOurWindow(title:String):Int;
	static function VisibleWindowCount():Int;
	static function StartWatch():Void;
	static function SeenOnADisplay():String;
	static function StopWatch():Void;
	static function PollCount():Int;
}

/**
 * A real window put off every display and never activated, driven only through AppDriver. The input
 * has to reach HaxeUI as it would from a user, with no focus taken from anyone: the window is never
 * active, the foreground window is never ours, and a click, typed text and a key all land. See
 * build.hxml for the exit codes.
 */
class Main {
	static inline var SETTLE_MS = 1500;
	static inline var STEP_MS = 200;
	static inline var MIN_POLLS = 100; // one poll takes well under a millisecond, and the window settles after 1.5 s
	static inline var RED = 0xFF0000;
	static inline var TITLE = "drive-window-app";
	static inline var WATCHDOG_SECONDS = 30;
	static inline var RESIZE_OVER_MS = 1200;
	static inline var WS_EX_TOOLWINDOW = 0x80;
	static inline var WS_EX_NOACTIVATE = 0x08000000;

	static var app:HaxeUIApp;
	static var field:TextField;
	static var button:Button;
	static var clicks = 0;
	static var queue:Array<Void->Void>;
	static var pickers:Array<PickerListener>;
	static var closedCallbackRan = false;
	static var windowsBefore = 0;
	static var pickersDeadline = 0.0;

	static function fail(code:Int, reason:String):Void {
		Sys.println('drive-window-app: FAILED (exit $code): $reason');
		Host.Exit(code);
	}

	static function main() {
		// First of all, before the window exists: a thread that sees every visible window of ours and where it is.
		Win32Probe.StartWatch();
		// A thread of its own (a background one), so it ends the process even if the UI thread hangs.
		sys.thread.Thread.create(() -> {
			Sys.sleep(WATCHDOG_SECONDS);
			Sys.println('drive-window-app: watchdog, the run took over ${WATCHDOG_SECONDS}s');
			cs.system.Environment.Exit(9);
		});
		AppDriver.SetWindow(true);
		app = new HaxeUIApp({
			width: 640,
			height: 480,
			title: TITLE
		});
		app.ready(function() {
			// One root component: FocusManager.instance.focus looks only under the topmost one.
			var root = new Absolute();
			root.percentWidth = 100;
			root.percentHeight = 100;
			field = new TextField();
			field.left = 20;
			field.top = 20;
			field.width = 200;
			root.addComponent(field);
			button = new Button();
			button.text = "Press";
			button.left = 20;
			button.top = 80;
			button.width = 120;
			button.height = 40;
			button.backgroundColor = RED;
			button.onClick = e -> clicks++;
			root.addComponent(button);
			app.addComponent(root);
			app.start();
			// the window has to settle (shown, laid out, drawn) before anything is checked
			Timer.delay(() -> run([
				neverOnADisplay,
				offDisplay,
				windowStyles,
				notActive,
				notForeground,
				clickButton,
				buttonGotIt,
				clickField,
				fieldHasFocus,
				typeText,
				fieldHasText,
				backspace,
				fieldHasBackspaced,
				askForPickers,
				pickersAreRefused,
				notActive,
				notForeground,
				capture
			]), SETTLE_MS);
		}, function() {
			// The end of the app (what Host's Closed handler tells it, and then exits): AppDriver.OnClosed's callback
			// must have run by now, or a driver's cleanup (Channel's drive.json) would be left behind by an app's own close.
			if (!closedCallbackRan) {
				return fail(13, "the window closed, the app was told of it, and AppDriver.OnClosed's callback had not run");
			}
			Sys.println("drive-window-app: AppDriver.OnClosed's callback ran before the app was told of the close");
			Sys.println("drive-window-app: ok");
		});
	}

	/** Each step on a turn of its own, so the window lays out and draws between them. The last, resize, ends the run. */
	static function run(steps:Array<Void->Void>):Void {
		if (steps.length == 0) {
			resize();
			return;
		}
		queue = steps; // a step still waiting on something puts itself back at the front
		var step = steps.shift();
		step();
		Timer.delay(() -> run(steps), STEP_MS);
	}

	/**
	 * The watch started in main has, polling about every millisecond since before the window existed, seen
	 * no visible window of this process on any display (even for an instant, which offDisplay below cannot see).
	 */
	static function neverOnADisplay():Void {
		var seen = Win32Probe.SeenOnADisplay();
		if (seen != "") {
			fail(12, 'a visible window of this process was on a display at $seen before it was settled off screen');
		} else if (Win32Probe.PollCount() < MIN_POLLS) {
			// a watch whose every poll failed would have seen nothing, and passed
			fail(12, 'the watch completed only ${Win32Probe.PollCount()} polls (at least $MIN_POLLS expected) before the window settled, so it proves nothing');
		} else {
			Sys.println('drive-window-app: the watch completed ${Win32Probe.PollCount()} polls before the window settled');
		}
	}

	static function offDisplay():Void {
		if (AppDriver.WindowIsOnADisplay) {
			fail(2, "the window is on a display");
		}
	}

	/** Read from Windows itself (GetWindowLong), not from Avalonia: both bits must be on the real window. */
	static function windowStyles():Void {
		stylesHold("");
	}

	/** Also read once the Resize has taken effect: a restyle after creation must not have dropped them. */
	static function stylesHold(when:String):Bool {
		var ex = Win32Probe.ExStyleOfOurWindow(TITLE);
		var want = WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
		if (ex < 0) {
			fail(11, 'no window of ours with the title was found to read its styles$when');
		} else if ((ex & want) != want) {
			fail(11, 'the window\'s extended styles are 0x${StringTools.hex(ex, 8)}, without WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE (0x${StringTools.hex(want, 8)})$when');
		} else {
			Sys.println('drive-window-app: extended styles 0x${StringTools.hex(ex, 8)} hold WS_EX_TOOLWINDOW and WS_EX_NOACTIVATE$when');
			return true;
		}
		return false;
	}

	static function notActive():Void {
		if (AppDriver.WindowIsActive) {
			fail(3, "the window is active");
		}
	}

	static function notForeground():Void {
		if (Win32Probe.ForegroundIsOurs() == 1) {
			fail(4, "the foreground window is ours");
		}
	}

	static function clickAt(c:Component):Void {
		var x = c.screenLeft + c.actualComponentWidth / 2;
		var y = c.screenTop + c.actualComponentHeight / 2;
		AppDriver.MouseMove(x, y);
		AppDriver.MouseDown(x, y, 0);
		AppDriver.MouseUp(x, y, 0);
	}

	static function clickButton():Void {
		clickAt(button);
	}

	// What an input did is read in the step after it, once the window has had a turn.
	static function buttonGotIt():Void {
		if (clicks != 1) {
			fail(5, 'the Button was clicked and got $clicks CLICK events');
		}
	}

	static function clickField():Void {
		if (field.focus) {
			return fail(1, "setup: the TextField had focus before it was clicked, so its focus would prove nothing");
		}
		clickAt(field);
	}

	static function fieldHasFocus():Void {
		if (FocusManager.instance.focus != field) {
			fail(10, 'focus: a click on the TextField left the focus on ${FocusManager.instance.focus}');
		}
	}

	static function typeText():Void {
		AppDriver.Text("abc");
	}

	static function fieldHasText():Void {
		if (field.text != "abc") {
			fail(10, 'text: Text("abc") left the TextField with "${field.text}"');
		}
	}

	static function backspace():Void {
		var back = AppDriver.KeyCode("Back");
		AppDriver.KeyDown(back);
		AppDriver.KeyUp(back);
	}

	static function fieldHasBackspaced():Void {
		if (field.text != "ab") {
			fail(10, 'key: Back left the TextField with "${field.text}"');
		}
	}

	/** A driven build opens no native picker: it would take the user's focus. Each ask is answered as cancelled instead. */
	static function askForPickers():Void {
		FileDialogs.TestResponse = null;
		windowsBefore = Win32Probe.VisibleWindowCount();
		pickersDeadline = Sys.time() + 1.0;
		pickers = [new PickerListener(), new PickerListener(), new PickerListener()];
		var none = new cs.NativeArray<String>(0);
		FileDialogs.OpenFiles("Open", false, none, none, pickers[0]);
		FileDialogs.SaveFile("Save", "a.txt", none, none, pickers[1]);
		FileDialogs.OpenFolder("Folder", false, null, pickers[2]);
	}

	static function pickersAreRefused():Void {
		var waiting = [for (p in pickers) if (p.cancelled == 0) p];
		if (waiting.length > 0 && Sys.time() < pickersDeadline) {
			queue.unshift(pickersAreRefused);
			return;
		}
		if (waiting.length > 0) {
			return fail(8, '${waiting.length} of 3 file pickers (OpenFiles, SaveFile, OpenFolder) were not answered as cancelled within a second');
		}
		var answered = 0;
		for (p in pickers) {
			answered += p.files;
		}
		var windowsAfter = Win32Probe.VisibleWindowCount();
		if (answered > 0) {
			fail(8, 'a file picker answered with files');
		} else if (windowsAfter != windowsBefore) {
			fail(8, 'the process had $windowsBefore visible windows before the file pickers were asked for and $windowsAfter after');
		} else {
			Sys.println('drive-window-app: 3 file pickers answered as cancelled, still $windowsAfter visible windows');
		}
	}

	static function capture():Void {
		var png = AppDriver.CapturePng(0, 0, 0, 0);
		if (png == null) {
			return fail(6, "CapturePng answered nothing");
		}
		var bytes = haxe.io.Bytes.ofData(png);
		var found = redPixels(bytes);
		if (found == 0) {
			fail(6, 'the capture of ${bytes.length} bytes holds no pixel of the Button\'s colour');
		} else {
			Sys.println('drive-window-app: capture holds $found pixels of the Button\'s colour');
		}
	}

	static function near(a:Float, b:Float):Bool {
		return Math.abs(a - b) < 0.5; // what Resize's own correction takes as the size asked for
	}

	/** The last step: the poll ends the run, with exit 7 on timeout, so it cannot pass by being cut short. */
	static function resize():Void {
		AppDriver.Resize(500, 400);
		var deadline = Sys.time() + 1.0;
		var check:Void->Void = null;
		check = function() {
			if (near(Host.ClientWidth, 500) && near(Host.ClientHeight, 400)) {
				if (stylesHold(" (after Resize)")) {
					// past Resize's second, its correction must be gone
					Timer.delay(resizeIsOver, RESIZE_OVER_MS);
				}
				return;
			}
			if (Sys.time() > deadline) {
				return fail(7, 'Resize(500, 400) left the client area ${Host.ClientWidth}x${Host.ClientHeight} a second later');
			}
			Timer.delay(check, 20);
		};
		check();
	}

	/**
	 * A later size change must not be pushed back towards the 500 x 400 asked for. The window is set
	 * directly to something else (its Width and Height are 6 x 17 off the client size, so only
	 * "not 500 x 400" is asserted).
	 */
	static function resizeIsOver():Void {
		Host.Window.Width = 450;
		Host.Window.Height = 350;
		Timer.delay(() -> {
			if (near(Host.ClientWidth, 500) || near(Host.ClientHeight, 400)) {
				fail(7, 'a size set directly after Resize\'s second was pushed back to ${Host.ClientWidth}x${Host.ClientHeight}');
			} else {
				var seen = Win32Probe.SeenOnADisplay();
				Win32Probe.StopWatch();
				if (seen != "") {
					return fail(12, 'a visible window of this process was on a display at $seen');
				}
				Sys.println('drive-window-app: a later size change stays (client ${Host.ClientWidth}x${Host.ClientHeight})');
				Sys.println('drive-window-app: no visible window of this process was ever on a display');
				AppDriver.OnClosed(Callbacks.callback(() -> closedCallbackRan = true));
				app.exit();
			}
		}, 300);
	}

	static function bigEndian(png:haxe.io.Bytes, at:Int):Int {
		return (png.get(at) << 24) | (png.get(at + 1) << 16) | (png.get(at + 2) << 8) | png.get(at + 3);
	}

	/** How many pixels of an 8-bit RGB(A) PNG are exactly RED: its IDAT chunks inflated, then each row unfiltered. */
	static function redPixels(png:haxe.io.Bytes):Int {
		var width = bigEndian(png, 16);
		var height = bigEndian(png, 20);
		var colorType = png.get(25);
		var channels = colorType == 6 ? 4 : 3;
		if (png.get(24) != 8 || (colorType != 6 && colorType != 2) || png.get(28) != 0) {
			throw "not an 8-bit RGB(A) PNG, not interlaced";
		}
		var idat = new haxe.io.BytesBuffer();
		var at = 8;
		while (at < png.length) {
			var length = bigEndian(png, at);
			if (png.getString(at + 4, 4) == "IDAT") {
				idat.addBytes(png, at + 8, length);
			}
			at += 12 + length;
		}
		var raw = haxe.zip.Uncompress.run(idat.getBytes());
		var stride = width * channels;
		var previous = haxe.io.Bytes.alloc(stride);
		var count = 0;
		for (row in 0...height) {
			var line = haxe.io.Bytes.alloc(stride);
			var start = row * (stride + 1);
			var filter = raw.get(start);
			for (i in 0...stride) {
				var value = raw.get(start + 1 + i);
				var left = i >= channels ? line.get(i - channels) : 0;
				var up = previous.get(i);
				var upLeft = i >= channels ? previous.get(i - channels) : 0;
				line.set(i, (value + switch (filter) {
					case 1: left;
					case 2: up;
					case 3: (left + up) >> 1;
					case 4: paeth(left, up, upLeft);
					default: 0;
				}) & 0xFF);
			}
			for (x in 0...width) {
				var o = x * channels;
				if (((line.get(o) << 16) | (line.get(o + 1) << 8) | line.get(o + 2)) == RED) {
					count++;
				}
			}
			previous = line;
		}
		return count;
	}

	static function paeth(a:Int, b:Int, c:Int):Int {
		var p = a + b - c;
		var pa = Std.int(Math.abs(p - a)), pb = Std.int(Math.abs(p - b)), pc = Std.int(Math.abs(p - c));
		return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
	}
}

/** Counts how a file dialog ended. */
private class PickerListener implements IFileDialogListener {
	public var files = 0;
	public var cancelled = 0;

	public function new() {
	}

	public function OnFiles(paths:cs.NativeArray<String>):Void {
		files++;
	}

	public function OnCancelled():Void {
		cancelled++;
	}

	public function OnFailed(message:String):Void {
	}
}
