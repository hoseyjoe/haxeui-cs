package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.system.IDisposable;
import cs.types.Int64;
import cs.types.UInt8;

/**
 * Externs for .NET's own types (`System.*`), written by hand as hxc binds them: each carries its real
 * name, and `@:overload` where .NET has more than one.
 */
@:native("System.Collections.Generic.IReadOnlyCollection`1")
extern class IReadOnlyCollection<T> {
	var Count(default, never):Int;
}

@:native("System.Collections.Generic.IReadOnlyList`1")
extern class IReadOnlyList<T> extends IReadOnlyCollection<T> implements ArrayAccess<T> {}

@:native("System.IO.Stream")
extern class Stream implements IDisposable {
	var Length(get, never):Int64;
	function get_Length():Int64;
	var Position(get, never):Int64;
	function get_Position():Int64;
	@:overload function Read(buffer:NativeArray<UInt8>, offset:Int, count:Int):Int;
	@:overload function CopyTo(destination:Stream):Void;
	@:overload function Write(buffer:NativeArray<UInt8>, offset:Int, count:Int):Void;
	function Dispose():Void;
}

@:native("System.IO.MemoryStream")
extern class MemoryStream extends Stream {
	@:overload function new();
	@:overload function new(buffer:NativeArray<UInt8>);
	@:overload function new(buffer:NativeArray<UInt8>, writable:Bool);
	@:overload function new(buffer:NativeArray<UInt8>, index:Int, count:Int, writable:Bool);
	function ToArray():NativeArray<UInt8>;
}

@:native("System.IO.Compression.CompressionMode")
extern enum CompressionMode {
	Decompress;
	Compress;
}

@:native("System.IO.Compression.ZLibCompressionOptions")
extern class ZLibCompressionOptions {
	function new();
	var CompressionLevel:Int;
}

@:native("System.IO.Compression.ZLibStream")
extern class ZLibStream extends Stream {
	@:overload function new(stream:Stream, mode:CompressionMode);
	@:overload function new(stream:Stream, options:ZLibCompressionOptions, leaveOpen:Bool);
}

@:native("System.IO.Compression.DeflateStream")
extern class DeflateStream extends Stream {
	@:overload function new(stream:Stream, mode:CompressionMode);
}

@:native("System.IO.Compression.GZipStream")
extern class GZipStream extends Stream {
	@:overload function new(stream:Stream, mode:CompressionMode);
}


/**
 * C#'s `using`, which Haxe has no `finally` to write: disposes `x` however the body ends. A body on
 * the render thread can't use these, as they take a closure.
 */
@:native("System.Net.WebUtility")
extern class WebUtility {
	@:overload static function HtmlDecode(value:String):String;
}

class Scope {
	public static function run(x:IDisposable, body:() -> Void):Void {
		try {
			body();
		} catch (e:Dynamic) {
			x.Dispose();
			throw e;
		}
		x.Dispose();
	}

	public static function get<R>(x:IDisposable, body:() -> R):R {
		var result:R;
		try {
			result = body();
		} catch (e:Dynamic) {
			x.Dispose();
			throw e;
		}
		x.Dispose();
		return result;
	}
}
