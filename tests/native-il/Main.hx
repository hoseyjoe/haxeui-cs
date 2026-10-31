import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.Deflate;
import haxe.ui.backend.cs.native.impl.Inflate;

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

	static function main() {
		testCompress();
		if (failed > 0) {
			Sys.exit(1);
		}
		Sys.println("native-il ok");
	}
}
