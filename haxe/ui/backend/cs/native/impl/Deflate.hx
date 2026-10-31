package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Net;

/**
 * zlib's compress, for haxe.zip.Compress (macros/NativeCompress.hx): Haxe 4.3's C# std leaves
 * Compress unimplemented, so nothing built on it (a KDBX or zip writer, a PNG encoder) can run.
 */
@:native("HaxeUICs.Deflate")
@:nativeGen
class Deflate {
	/**
	 * A zlib stream (header, deflate, Adler-32) of the bytes, at zlib's level 0..9 (-1: its
	 * default, 6), as zlib's compress2 makes it.
	 */
	public static function Run(data:NativeArray<UInt8>, offset:Int, length:Int, level:Int):NativeArray<UInt8> {
		var output = new MemoryStream();
		return Scope.get(output, () -> {
			var options = new ZLibCompressionOptions();
			options.CompressionLevel = level < -1 ? -1 : level > 9 ? 9 : level;
			var deflater = new ZLibStream(output, options, true);
			Scope.run(deflater, () -> deflater.Write(data, offset, length));
			return output.ToArray();
		});
	}
}
