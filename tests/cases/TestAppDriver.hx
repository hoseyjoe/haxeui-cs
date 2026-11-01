package cases;

#if haxeui_cs_drive
import cs.NativeArray;
import cs.system.Console;
import cs.system.io.StringWriter;
import cs.types.UInt8;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native.AppDriver;
import haxe.ui.backend.cs.native.Native.FileDialogs;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.Native.IFileDialogListener;
import haxe.ui.components.Button;
import haxe.ui.components.TextField;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;
import utest.Assert;

/**
 * AppDriver: input handed to the window as raw Avalonia events, and the window captured as a PNG.
 * Input goes only through AppDriver here; TestDriver is just the pump and where things are.
 */
class TestAppDriver extends utest.Test {
	function teardown() {
		AppDriver.MouseMove(790, 590);
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testClick() {
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		var c = TestDriver.centerOf(button);
		AppDriver.MouseMove(c.x, c.y);
		AppDriver.MouseDown(c.x, c.y, 0);
		AppDriver.MouseUp(c.x, c.y, 0);
		TestDriver.pump();
		Assert.equals(1, clicks);
	}

	function testRightClick() {
		var button = addButton();
		var rightClicks = 0;
		var clicks = 0;
		button.registerEvent(MouseEvent.RIGHT_CLICK, e -> rightClicks++);
		button.onClick = e -> clicks++;
		var c = TestDriver.centerOf(button);
		AppDriver.MouseMove(c.x, c.y);
		AppDriver.MouseDown(c.x, c.y, 2);
		AppDriver.MouseUp(c.x, c.y, 2);
		TestDriver.pump();
		Assert.equals(1, rightClicks);
		Assert.equals(0, clicks);
	}

	function testWheelDirection() {
		var box = new Box();
		box.left = 20;
		box.top = 20;
		box.width = 100;
		box.height = 100;
		Screen.instance.addComponent(box);
		TestDriver.pump(2);
		var deltas:Array<Float> = [];
		box.registerEvent(MouseEvent.MOUSE_WHEEL, e -> deltas.push(e.delta));
		var c = TestDriver.centerOf(box);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.wheel(c.x, c.y, -1);
		TestDriver.pump();
		AppDriver.Wheel(c.x, c.y, -1, 0);
		TestDriver.pump();
		Assert.equals(2, deltas.length);
		Assert.isTrue(deltas[0] != 0, "the reference wheel gave a delta");
		Assert.equals(deltas[0], deltas[1]);
	}

	function testTextAndBackspace() {
		var field = addTextField();
		click(field);
		AppDriver.Text("abc");
		TestDriver.pump(2);
		Assert.equals("abc", field.text);
		var back = AppDriver.KeyCode("Back");
		AppDriver.KeyDown(back);
		AppDriver.KeyUp(back);
		TestDriver.pump(2);
		Assert.equals("ab", field.text);
	}

	function testCtrlAReplaces() {
		var field = addTextField();
		click(field);
		AppDriver.Text("abc");
		TestDriver.pump(2);
		Assert.equals("abc", field.text);
		var ctrl = AppDriver.KeyCode("LeftCtrl");
		var a = AppDriver.KeyCode("A");
		AppDriver.KeyDown(ctrl);
		AppDriver.KeyDown(a);
		AppDriver.KeyUp(a);
		AppDriver.KeyUp(ctrl);
		TestDriver.pump(2);
		AppDriver.Text("x");
		TestDriver.pump(2);
		Assert.equals("x", field.text);
	}

	function testSeparateClicksSelectNoWord() {
		// Two clicks a driver sends back to back are two clicks: NewClick starts each, so the second is
		// not counted with the first as a double click (which would select the word under it).
		var field = addTextField();
		field.text = "hello world";
		TestDriver.pump(2);
		AppDriver.NewClick();
		click(field);
		AppDriver.NewClick();
		click(field);
		Assert.equals(0, selected(field), "the second click selected nothing");
	}

	function testWithoutNewClickTheSecondIsADoubleClick() {
		// What NewClick is for: the same two clicks without it, and the word under the second is selected.
		var field = addTextField();
		field.text = "hello world";
		TestDriver.pump(2);
		click(field);
		click(field);
		Assert.isTrue(selected(field) > 0, "the second click selected a word");
	}

	function testTwoPressesInOneClickSelectAWord() {
		// A double click is two presses with no NewClick between: it still selects.
		var field = addTextField();
		field.text = "hello world";
		TestDriver.pump(2);
		AppDriver.NewClick();
		var p = TestDriver.centerOf(field);
		AppDriver.MouseMove(p.x, p.y);
		for (_ in 0...2) {
			AppDriver.MouseDown(p.x, p.y, 0);
			AppDriver.MouseUp(p.x, p.y, 0);
		}
		TestDriver.pump(2);
		Assert.isTrue(selected(field) > 0, "a double click selected a word");
	}

	function testNewClickWhileAButtonIsHeldChangesNothing() {
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		var c = TestDriver.centerOf(button);
		AppDriver.MouseMove(c.x, c.y);
		AppDriver.MouseDown(c.x, c.y, 0);
		AppDriver.NewClick(); // mid-press: the press under way keeps its device, and so its release
		AppDriver.MouseUp(c.x, c.y, 0);
		TestDriver.pump(2);
		Assert.equals(1, clicks);
	}

	function testNewClickRaisesNoExitOrEnter() {
		// The pointer is already over the button: starting a new click there must not look, to the
		// button, like the pointer leaving and coming back (tooltips and close-on-out popups would run).
		var button = addButton();
		var outs = 0;
		var overs = 0;
		button.registerEvent(MouseEvent.MOUSE_OUT, e -> outs++);
		button.registerEvent(MouseEvent.MOUSE_OVER, e -> overs++);
		var c = TestDriver.centerOf(button);
		AppDriver.MouseMove(c.x, c.y);
		TestDriver.pump(2);
		Assert.equals(1, overs, "setup: the pointer is over the button");
		AppDriver.NewClick();
		click(button);
		AppDriver.NewClick();
		click(button);
		Assert.equals(0, outs, "no exit");
		Assert.equals(1, overs, "no second enter");
	}

	function testKeyCodeReachesHaxeUI() {
		var codes:Array<Int> = [];
		var listener = (e:KeyboardEvent) -> codes.push(e.keyCode);
		Screen.instance.registerEvent(KeyboardEvent.KEY_DOWN, listener);
		var enter = AppDriver.KeyCode("Enter");
		AppDriver.KeyDown(enter);
		AppDriver.KeyUp(enter);
		TestDriver.pump();
		Screen.instance.unregisterEvent(KeyboardEvent.KEY_DOWN, listener);
		Assert.same([13], codes);
	}

	function testUnknownKey() {
		Assert.equals(-1, AppDriver.KeyCode("NoSuchKey"));
		Assert.isTrue(AppDriver.KeyCode("A") > 0);
	}

	function testCtrlStaysWhileEitherCtrlIsHeld() {
		var field = addTextField();
		click(field);
		AppDriver.Text("abc");
		TestDriver.pump(2);
		var left = AppDriver.KeyCode("LeftCtrl");
		var right = AppDriver.KeyCode("RightCtrl");
		var a = AppDriver.KeyCode("A");
		AppDriver.KeyDown(left);
		AppDriver.KeyDown(right);
		AppDriver.KeyUp(right); // the left one is still down
		AppDriver.KeyDown(a);
		AppDriver.KeyUp(a);
		AppDriver.KeyUp(left);
		TestDriver.pump(2);
		AppDriver.Text("x");
		TestDriver.pump(2);
		Assert.equals("x", field.text, "Ctrl+A still selected everything");
		// and with both let go, A alone selects nothing
		AppDriver.KeyDown(a);
		AppDriver.KeyUp(a);
		TestDriver.pump(2);
		AppDriver.Text("y");
		TestDriver.pump(2);
		Assert.equals("xy", field.text);
	}

	function testNotAKeyCode() {
		Assert.raises(() -> AppDriver.KeyDown(-1), String);
		Assert.raises(() -> AppDriver.KeyUp(-1), String);
		Assert.raises(() -> AppDriver.KeyDown(AppDriver.KeyCode("NoSuchKey")), String);
	}

	function testNotAButton() {
		Assert.raises(() -> AppDriver.MouseDown(30, 30, 3), String);
		Assert.raises(() -> AppDriver.MouseUp(30, 30, 3), String);
		Assert.raises(() -> AppDriver.MouseDown(30, 30, -1), String);
	}

	function testNoWindowIsAClearError() {
		var window = Host.Window;
		var message:String = null;
		@:privateAccess Host.Window = null;
		try {
			AppDriver.Text("a");
		} catch (e:Dynamic) {
			message = "" + e;
		}
		var keyMessage:String = null;
		try {
			AppDriver.KeyDown(AppDriver.KeyCode("A"));
		} catch (e:Dynamic) {
			keyMessage = "" + e;
		}
		var wheelMessage:String = null;
		try {
			AppDriver.Wheel(1, 1, 1, 0);
		} catch (e:Dynamic) {
			wheelMessage = "" + e;
		}
		var capture = AppDriver.CapturePng(0, 0, 0, 0);
		@:privateAccess Host.Window = window;
		Assert.equals("AppDriver: the window does not exist yet", message);
		Assert.equals("AppDriver: the window does not exist yet", keyMessage);
		Assert.equals("AppDriver: the window does not exist yet", wheelMessage);
		Assert.isNull(capture);
		// the refused KeyDown did not leave A held: a later key is not affected
		AppDriver.KeyUp(AppDriver.KeyCode("A"));
	}

	function testCapture() {
		addButton();
		var whole = AppDriver.CapturePng(0, 0, 0, 0);
		Assert.notNull(whole);
		assertPng(whole);
		// the same rounding as Host.CaptureWindow's
		Assert.equals(Std.int(Math.max(1, Host.ClientWidth)), pngWidth(whole));
		Assert.equals(Std.int(Math.max(1, Host.ClientHeight)), pngHeight(whole));

		var part = AppDriver.CapturePng(10, 10, 20, 20);
		Assert.notNull(part);
		assertPng(part);
		Assert.equals(20, pngWidth(part));
		Assert.equals(20, pngHeight(part));

		Assert.isNull(AppDriver.CapturePng(100000, 0, 10, 10));
		Assert.isNull(AppDriver.CapturePng(-50, -50, 40, 40));
		Assert.isNull(AppDriver.CapturePng(10, 10, 20, 0));
	}

	function testCaptureOffsets() {
		// a red square at (100, 100), 50 x 50, on the window's white
		var box = new Box();
		box.left = 100;
		box.top = 100;
		box.width = 50;
		box.height = 50;
		box.backgroundColor = 0xFF0000;
		Screen.instance.addComponent(box);
		TestDriver.pump(3);
		Assert.equals(0xFF0000, TestDriver.pixel(125, 125) & 0xFFFFFF, "the square is where the test thinks");
		Assert.notEquals(0xFF0000, TestDriver.pixel(95, 95) & 0xFFFFFF);

		// 95..125: the square's corner is at (5, 5)
		var part = AppDriver.CapturePng(95, 95, 30, 30);
		Assert.equals(30, pngWidth(part));
		Assert.notEquals(0xFF0000, pixelAt(part, 2, 2) & 0xFFFFFF);
		Assert.notEquals(0xFF0000, pixelAt(part, 4, 20) & 0xFFFFFF);
		Assert.notEquals(0xFF0000, pixelAt(part, 20, 4) & 0xFFFFFF);
		Assert.equals(0xFF0000, pixelAt(part, 6, 6) & 0xFFFFFF);
		Assert.equals(0xFF0000, pixelAt(part, 25, 25) & 0xFFFFFF);

		// off the top left: cut to the window, not shifted. Window columns 0..120, rows 95..115.
		var cut = AppDriver.CapturePng(-10, 95, 130, 20);
		Assert.equals(120, pngWidth(cut));
		Assert.equals(20, pngHeight(cut));
		Assert.notEquals(0xFF0000, pixelAt(cut, 99, 10) & 0xFFFFFF);
		Assert.equals(0xFF0000, pixelAt(cut, 101, 10) & 0xFFFFFF);
		Assert.notEquals(0xFF0000, pixelAt(cut, 101, 3) & 0xFFFFFF);
		var top = AppDriver.CapturePng(95, -10, 30, 120);
		Assert.equals(30, pngWidth(top));
		Assert.equals(110, pngHeight(top));
		Assert.equals(0xFF0000, pixelAt(top, 10, 105) & 0xFFFFFF); // window (105, 105)
		Assert.notEquals(0xFF0000, pixelAt(top, 10, 97) & 0xFFFFFF); // window (105, 97)

		// off the bottom right: the part of it inside
		var w = Std.int(Host.ClientWidth);
		var h = Std.int(Host.ClientHeight);
		var corner = AppDriver.CapturePng(w - 10, h - 10, 30, 30);
		Assert.equals(10, pngWidth(corner));
		Assert.equals(10, pngHeight(corner));
	}

	function testDrivenBuildOpensNoFilePicker() {
		var before = FileDialogs.TestResponse;
		FileDialogs.TestResponse = null;
		var old = Console.Error;
		var captured = new StringWriter();
		var open = new PickerListener();
		var save = new PickerListener();
		var folder = new PickerListener();
		try {
			Console.SetError(captured);
			FileDialogs.OpenFiles("Open it", false, new NativeArray<String>(0), new NativeArray<String>(0), open);
			FileDialogs.SaveFile("Save it", "a.txt", new NativeArray<String>(0), new NativeArray<String>(0), save);
			FileDialogs.OpenFolder("Pick it", false, null, folder);
		} catch (e:Dynamic) {
			Console.SetError(old);
			FileDialogs.TestResponse = before;
			throw e;
		}
		Console.SetError(old);
		FileDialogs.TestResponse = before;
		TestDriver.pump(2);
		var written = captured.ToString();
		Assert.equals(1, open.cancelled, "OpenFiles answered cancelled");
		Assert.equals(1, save.cancelled, "SaveFile answered cancelled");
		Assert.equals(1, folder.cancelled, "OpenFolder answered cancelled");
		Assert.equals(0, open.files + save.files + folder.files);
		Assert.isTrue(written.indexOf("haxeui-cs: a driven build opens no file picker (Open it): answered as cancelled") >= 0, 'OpenFiles named itself: $written');
		Assert.isTrue(written.indexOf("haxeui-cs: a driven build opens no file picker (Save it): answered as cancelled") >= 0, 'SaveFile named itself: $written');
		Assert.isTrue(written.indexOf("haxeui-cs: a driven build opens no file picker (Pick it): answered as cancelled") >= 0, 'OpenFolder named itself: $written');
	}

	function testAnsweredDialogsStillAnswer() {
		var before = FileDialogs.TestResponse;
		var old = Console.Error;
		var captured = new StringWriter();
		var listener = new PickerListener();
		var answer = new NativeArray<String>(1);
		answer[0] = "some/path.txt";
		try {
			Console.SetError(captured);
			FileDialogs.TestResponse = answer;
			FileDialogs.OpenFiles("Open it", false, new NativeArray<String>(0), new NativeArray<String>(0), listener);
			FileDialogs.SaveFile("Save it", "a.txt", new NativeArray<String>(0), new NativeArray<String>(0), listener);
			FileDialogs.OpenFolder("Pick it", false, null, listener);
		} catch (e:Dynamic) {
			Console.SetError(old);
			FileDialogs.TestResponse = before;
			throw e;
		}
		Console.SetError(old);
		FileDialogs.TestResponse = before;
		Assert.equals(3, listener.files);
		Assert.equals(0, listener.cancelled);
		Assert.equals("", captured.ToString(), "an answered dialog writes no refusal");
	}

	function addButton():Button {
		var button = new Button();
		button.text = "Press";
		button.left = 20;
		button.top = 20;
		Screen.instance.addComponent(button);
		TestDriver.pump(2);
		return button;
	}

	function addTextField():TextField {
		var field = new TextField();
		field.left = 20;
		field.top = 20;
		field.width = 200;
		Screen.instance.addComponent(field);
		TestDriver.pump(2);
		return field;
	}

	function selected(field:TextField):Int {
		return field.selectionEndIndex - field.selectionStartIndex;
	}

	function click(c:Component) {
		var p = TestDriver.centerOf(c);
		AppDriver.MouseMove(p.x, p.y);
		AppDriver.MouseDown(p.x, p.y, 0);
		AppDriver.MouseUp(p.x, p.y, 0);
		TestDriver.pump(2);
	}

	static function assertPng(bytes:NativeArray<UInt8>) {
		var head:Array<Int> = [for (i in 0...4) (bytes[i] : Int)];
		Assert.same([0x89, 0x50, 0x4E, 0x47], head);
	}

	/**
	 * ARGB of a pixel of an 8-bit RGB or RGBA PNG: its IDAT chunks inflated and unfiltered, row by row
	 * up to the one asked for.
	 */
	static function pixelAt(bytes:NativeArray<UInt8>, x:Int, y:Int):Int {
		var png = haxe.io.Bytes.ofData(bytes);
		var width = bigEndian(bytes, 16);
		var colorType = png.get(25);
		var channels = colorType == 6 ? 4 : 3;
		Assert.isTrue(png.get(24) == 8 && (colorType == 6 || colorType == 2) && png.get(28) == 0, "an 8-bit RGB(A) PNG, not interlaced");
		var idat = new haxe.io.BytesBuffer();
		var at = 8;
		while (at < png.length) {
			var length = bigEndian(bytes, at);
			var type = png.getString(at + 4, 4);
			if (type == "IDAT") {
				idat.addBytes(png, at + 8, length);
			}
			at += 12 + length;
		}
		var raw = haxe.zip.Uncompress.run(idat.getBytes());
		var stride = width * channels;
		var rows:Array<haxe.io.Bytes> = [];
		for (row in 0...y + 1) {
			var line = haxe.io.Bytes.alloc(stride);
			var start = row * (stride + 1);
			var filter = raw.get(start);
			var previous = row > 0 ? rows[row - 1] : null;
			for (i in 0...stride) {
				var value = raw.get(start + 1 + i);
				var left = i >= channels ? line.get(i - channels) : 0;
				var up = previous != null ? previous.get(i) : 0;
				var upLeft = previous != null && i >= channels ? previous.get(i - channels) : 0;
				line.set(i, (value + switch (filter) {
					case 1: left;
					case 2: up;
					case 3: (left + up) >> 1;
					case 4: paeth(left, up, upLeft);
					default: 0;
				}) & 0xFF);
			}
			rows.push(line);
		}
		var line = rows[y];
		var o = x * channels;
		return ((channels == 4 ? line.get(o + 3) : 0xFF) << 24) | (line.get(o) << 16) | (line.get(o + 1) << 8) | line.get(o + 2);
	}

	static function paeth(a:Int, b:Int, c:Int):Int {
		var p = a + b - c;
		var pa = Std.int(Math.abs(p - a)), pb = Std.int(Math.abs(p - b)), pc = Std.int(Math.abs(p - c));
		return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
	}

	// IHDR: width and height are the big-endian ints at bytes 16 and 20.
	static function pngWidth(bytes:NativeArray<UInt8>):Int {
		return bigEndian(bytes, 16);
	}

	static function pngHeight(bytes:NativeArray<UInt8>):Int {
		return bigEndian(bytes, 20);
	}

	static function bigEndian(bytes:NativeArray<UInt8>, at:Int):Int {
		return ((bytes[at] : Int) << 24) | ((bytes[at + 1] : Int) << 16) | ((bytes[at + 2] : Int) << 8) | (bytes[at + 3] : Int);
	}
}

/** Counts how a file dialog ended. */
private class PickerListener implements IFileDialogListener {
	public var files = 0;
	public var cancelled = 0;

	public function new() {
	}

	public function OnFiles(paths:NativeArray<String>):Void {
		files++;
	}

	public function OnCancelled():Void {
		cancelled++;
	}

	public function OnFailed(message:String):Void {
	}
}
#end
