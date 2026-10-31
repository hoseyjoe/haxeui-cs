import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.Deflate;
import haxe.ui.backend.cs.native.impl.Inflate;
import haxe.ui.backend.cs.native.impl.UIFonts;

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

	static function main() {
		testCompress();
		testColorMatrix();
		testFonts();
		if (failed > 0) {
			Sys.exit(1);
		}
		Sys.println("native-il ok");
	}
}
