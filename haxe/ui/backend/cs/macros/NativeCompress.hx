package haxe.ui.backend.cs.macros;

#if macro
import haxe.macro.Expr;

/**
 * haxe.zip.Compress for C#, on .NET's System.IO.Compression (native/Deflate.cs): the twin of
 * NativeUncompress. Haxe 4.3's C# std has none (it throws "Not implemented for this platform"), so
 * nothing that writes compressed data could run: a KDBX database, a zip, a PNG.
 *
 * Hung on haxe.zip.Compress by Build.configure as a build macro, for NativeUncompress's reason.
 *
 * The output is a zlib stream, as `run` and the other targets make it. The first `execute` takes
 * the rest of `src` as all of the input, compresses it and reports all of it read; a `dst` too
 * small for the output is filled over further calls, until `done`. Feeding the input in pieces,
 * as zlib allows, is not supported.
 */
class NativeCompress {
	public static function build():Array<Field> {
		return (macro class Compress {
			var level:Int;
			var output:haxe.io.Bytes = null;
			var given:Int = 0;

			public function new(level:Int) {
				this.level = level;
			}

			public function execute(src:haxe.io.Bytes, srcPos:Int, dst:haxe.io.Bytes, dstPos:Int):{done:Bool, read:Int, write:Int} {
				var read = 0;
				if (output == null) {
					output = deflate(src, srcPos, src.length - srcPos, level);
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

			public static function run(s:haxe.io.Bytes, level:Int):haxe.io.Bytes {
				return deflate(s, 0, s.length, level);
			}

			static function deflate(src:haxe.io.Bytes, pos:Int, len:Int, level:Int):haxe.io.Bytes {
				return haxe.io.Bytes.ofData(haxe.ui.backend.cs.native.Native.Deflate.Run(src.getData(), pos, len, level));
			}
		}).fields;
	}
}
#end
