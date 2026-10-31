package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Net;

/**
 * zlib's inflate, for haxe.zip.Uncompress (macros/NativeUncompress.hx): Haxe 4.3's
 * C# std leaves Uncompress unimplemented, so no zip, EPUB or PNG reader built on it can run.
 */
@:native("HaxeUICs.Inflate")
@:nativeGen
class Inflate {
	/**
	 * Inflates a whole stream. windowBits reads as zlib reads it: 8..15 a zlib stream, -8..-15
	 * raw deflate (a zip entry), 24..31 gzip, 40..47 zlib or gzip by the stream's own header.
	 */
	public static function Run(data:NativeArray<UInt8>, offset:Int, length:Int, windowBits:Int):NativeArray<UInt8> {
		var gzip = windowBits > 31 ? length >= 2 && data[offset] == 0x1f && data[offset + 1] == 0x8b : windowBits > 15;
		var input = new MemoryStream(data, offset, length, false);
		return Scope.get(input, () -> {
			var inflater:Stream = if (windowBits < 0) {
				new DeflateStream(input, Decompress);
			} else if (gzip) {
				new GZipStream(input, Decompress);
			} else {
				new ZLibStream(input, Decompress);
			}
			return Scope.get(inflater, () -> {
				var output = new MemoryStream();
				return Scope.get(output, () -> {
					inflater.CopyTo(output);
					return output.ToArray();
				});
			});
		});
	}
}
