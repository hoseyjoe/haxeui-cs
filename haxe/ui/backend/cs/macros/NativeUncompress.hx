package haxe.ui.backend.cs.macros;

#if macro
import haxe.macro.Expr;

/**
 * haxe.zip.Uncompress for C#, on .NET's System.IO.Compression (native/Inflate.cs). Haxe 4.3's C#
 * std has none (its constructor throws "Not implemented for this platform"), so
 * `haxe.zip.Reader.unzip`, and every zip, EPUB or PNG reader built on it, failed on the first
 * compressed entry.
 *
 * Build.configure hangs this on haxe.zip.Uncompress as a build macro rather than putting a
 * replacement ahead of the std on the class path: a class path reaches the macro context too,
 * where an app may well unzip at compile time and C# externs cannot be typed.
 *
 * `windowBits` is zlib's: 15 (the default) a zlib stream, -15 raw deflate as a zip entry holds
 * it, 31 gzip, 47 either by its header.
 *
 * The first `execute` takes the rest of `src` as the whole compressed stream, inflates it and
 * reports all of it read; a `dst` too small for the output is filled over further calls, until
 * `done`. Feeding the input in pieces, as zlib allows, is not supported: every caller in the std
 * and in format hands the stream over in one piece.
 */
class NativeUncompress {
	public static function build():Array<Field> {
		return (macro class Uncompress {
			var windowBits:Int;
			var output:haxe.io.Bytes = null;
			var given:Int = 0;

			public function new(?windowBits:Int) {
				this.windowBits = windowBits == null ? 15 : windowBits;
			}

			public function execute(src:haxe.io.Bytes, srcPos:Int, dst:haxe.io.Bytes, dstPos:Int):{done:Bool, read:Int, write:Int} {
				var read = 0;
				if (output == null) {
					output = inflate(src, srcPos, src.length - srcPos, windowBits);
					read = src.length - srcPos;
				}
				var write = Std.int(Math.min(output.length - given, dst.length - dstPos));
				dst.blit(dstPos, output, given, write);
				given += write;
				return {done: given == output.length, read: read, write: write};
			}

			public function setFlushMode(f:haxe.zip.FlushMode) {}

			public function close() {
				output = null;
			}

			public static function run(src:haxe.io.Bytes, ?bufsize:Int):haxe.io.Bytes {
				return inflate(src, 0, src.length, 15);
			}

			static function inflate(src:haxe.io.Bytes, pos:Int, len:Int, windowBits:Int):haxe.io.Bytes {
				return haxe.io.Bytes.ofData(haxe.ui.backend.cs.native.Native.Inflate.Run(src.getData(), pos, len, windowBits));
			}
		}).fields;
	}
}
#end
