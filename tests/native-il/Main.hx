import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.Deflate;
import haxe.ui.backend.cs.native.impl.Inflate;
import haxe.ui.backend.cs.native.impl.PickedFiles;
import haxe.ui.backend.cs.native.impl.UIFonts;
import haxe.ui.backend.cs.native.impl.UILayers;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Media;

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

	static function main() {
		testCompress();
		testColorMatrix();
		testFonts();
		testPickedFiles();
		testLayers();
		if (failed > 0) {
			Sys.exit(1);
		}
		Sys.println("native-il ok");
	}
}
