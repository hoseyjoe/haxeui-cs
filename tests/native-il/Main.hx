import cs.NativeArray;
import cs.types.UInt8;
import cs.system.IntPtr;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.Deflate;
import haxe.ui.backend.cs.native.impl.Inflate;
import haxe.ui.backend.cs.native.impl.PickedFiles;
import haxe.ui.backend.cs.native.impl.Host;
import haxe.ui.backend.cs.native.impl.UIFonts;
import haxe.ui.backend.cs.native.impl.UIGraphics;
import haxe.ui.backend.cs.native.impl.UIImage;
import haxe.ui.backend.cs.native.impl.UIPanel;
import haxe.ui.backend.cs.native.impl.UIText;
import haxe.ui.backend.cs.native.impl.UILayers;
import haxe.ui.backend.cs.native.impl.UITextInput;
import haxe.ui.backend.cs.net.App;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Threading;
import haxe.ui.backend.cs.net.Media;

private class NoListener implements IHostListener {
	public function new() {}

	public function OnReady():Void {}

	public function OnResize(width:Float, height:Float):Void {}

	public function OnClosed():Void {}
}

/** The ported C# under hxc, with no HaxeUI around it. Exits non-zero on a failed check. */
class Main {
	static var failed = 0;

	static function check(name:String, ok:Bool) {
		if (!ok) {
			failed++;
			Sys.println("FAILED: " + name);
		}
	}

	static function testCompress() {
		var bytes = new NativeArray<UInt8>(1000);
		for (i in 0...1000) {
			bytes[i] = i * 7 % 256;
		}
		var packed = Deflate.Run(bytes, 0, 1000, -1);
		var back = Inflate.Run(packed, 0, packed.Length, 15);
		var same = back.Length == 1000;
		for (i in 0...1000) {
			same = same && back[i] == bytes[i];
		}
		check("a Deflate then Inflate round trip", same);
	}

	static function testColorMatrix() {
		var m = new NativeArray<Single>(20);
		for (i in [0, 6, 12, 18]) {
			m[i] = 1;
		}
		for (argb in [0xFFFFFFFF, 0x80FFFFFF, 0xFF000001]) {
			var colour:UInt = argb;
			check("identity keeps " + StringTools.hex(argb, 8), ColorMatrix.Apply(m, colour) == colour);
		}
	}

	static function testFonts() {
		check("monospace resolves", UIFonts.ResolveFamily("monospace") != null);
		check("bytes that are no font", UIFonts.FromBytes("not-a-font", new NativeArray<UInt8>(64)) == null);
	}

	static function testPickedFiles() {
		var dir = cs.system.io.Path.Combine(cs.system.io.Path.GetTempPath(), "haxeui-cs-native-il-" + Math.ffloor(Date.now().getTime()));
		var bytes = new NativeArray<UInt8>(10);
		var path = PickedFiles.ImportBytes(dir, "Book.epub", bytes, true, -1);
		check("an import lands under its name", haxe.io.Path.withoutDirectory(StringTools.replace(path, "\\", "/")) == "Book.epub");
		var threw = false;
		try {
			PickedFiles.ImportBytes(dir, "Other.epub", bytes, true, 2);
		} catch (e:Dynamic) {
			threw = Std.isOfType(e, cs.system.io.IOException);
		}
		check("a failed read is an IOException", threw);
		check("a failed import leaves nothing", sys.FileSystem.readDirectory(dir).length == 1);
		sys.FileSystem.deleteFile(path);
		sys.FileSystem.deleteDirectory(dir);
	}

	static function testLayers() {
		var draw:ICustomDrawOperation = new UILayersDraw(new NativeArray<UILayersNode>(0), new Rect(1, 2, 3, 4), null);
		check("a draw's bounds through its interface", draw.Bounds.Right == 4);
		var layers = new UILayers();
		var group = layers.AddGroup(-1);
		layers.AddBitmap(group);
		layers.SetMatrix(group, 2, 0, 0, 2, 0, 0);
		check("layers count", layers.Count == 2);
	}

	static function testTextInputCompiles() {
		// A control needs a running app: that it compiles is the check here.
		check("UITextInput is a class", Type.getClassName(UITextInput) != null);
	}

	/** The whole cycle in a real (headless) window: a panel, its text, an image and a drawing, as rendered. */
	static function testWindow() {
		Host.StartHeadless(new NoListener(), 200, 120);
		var panel = new UIPanel();
		panel.SetBounds(0, 0, 200, 120);
		Host.Root.InsertChild(panel, 0);

		var graphics = new UIGraphics();
		graphics.FillStyle(true, 0xFFFF0000);
		graphics.Rectangle(10, 10, 40, 40);
		panel.SetGraphics(graphics);

		var view = new UIImageView();
		view.SetImage(UIImage.FromBytes(sys.io.File.getBytes("tests/assets/red4x4.png").getData()));
		view.SetBounds(60, 10, 40, 40);
		panel.AddContent(view);

		var text = new UIText();
		text.SetFont("", 20, true, false, false, false);
		text.SetColor(0xFF000000);
		text.SetBounds(110, 10, 80, 40);
		text.Text = "Hxc";
		panel.AddContent(text);

		Dispatcher.UIThread.RunJobs(null);
		var frame = HeadlessWindowExtensions.CaptureRenderedFrame(Host.Window);
		var buffer = frame.Lock();
		function isRed(x:Int, y:Int):Bool {
			var px = new NativeArray<UInt8>(4);
			Marshal.Copy(IntPtr.Add(buffer.Address, y * buffer.RowBytes + x * 4), px, 0, 4);
			var bgr = px[0] == 0 && px[2] == 255;
			var rgb = px[0] == 255 && px[2] == 0;
			return px[1] == 0 && (bgr || rgb);
		}
		function dark(x:Int, y:Int):Bool {
			var px = new NativeArray<UInt8>(4);
			Marshal.Copy(IntPtr.Add(buffer.Address, y * buffer.RowBytes + x * 4), px, 0, 4);
			return px[1] < 128;
		}
		check("the drawing shows", isRed(30, 30));
		check("outside it does not", !isRed(5, 5));
		check("the image shows", isRed(80, 30));
		var inked = false;
		for (y in 10...50) {
			for (x in 110...190) {
				inked = inked || dark(x, y);
			}
		}
		check("the text shows", inked);
		buffer.Dispose();
	}

	static function main() {
		testWindow();
		testCompress();
		testColorMatrix();
		testFonts();
		testPickedFiles();
		testLayers();
		testTextInputCompiles();
		if (failed > 0) {
			Sys.exit(1);
		}
		Sys.println("native-il ok");
	}
}
