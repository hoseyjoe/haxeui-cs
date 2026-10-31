package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.DateTime;
import cs.system.Exception;
import cs.system.Func_1;
import cs.system.io.Directory;
import cs.system.io.File;
import cs.system.io.FileInfo;
import cs.system.io.IOException;
import cs.system.io.Path;
import cs.system.text.Encoding;
import cs.types.Int64;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Net;

/**
 * A document picked through Android's file picker, copied into the app's private storage so it
 * has a real path: the picker hands back a content URI that sys.io.File cannot open, and that
 * may not outlive the pick. The rules are heaps-android's (PickedFiles.kt), so a book picked
 * under either backend lands under the same name.
 */
@:native("HaxeUICs.PickedFiles")
@:nativeGen
class PickedFiles {
	static inline final PartSuffix = ".importing";

	/**
	 * ext4's limit on a name is 255 bytes, less what is added to one: the temporary's suffix and
	 * ` (99999)`.
	 */
	static inline final MaxNameBytes = 255 - 10 - 8;

	/** The longest extension kept when a name is cut; anything longer isn't one. */
	static inline final MaxExtensionBytes = 32;

	/**
	 * Copies the document into `dir` under its display name and returns the copy's absolute path.
	 * The same book picked again (a file of that name, or a suffixed one, with the same length)
	 * is not copied twice; another book with the same name goes to `Book (2).epub` and on. A
	 * `size` below 0 is unknown and can't be matched, so it always gets a fresh name. Any failure
	 * is an IOException, leaving nothing behind.
	 */
	public static function Import(dir:String, displayName:String, size:Int64, open:Func_1<Stream>):String {
		var part:String = null;
		try {
			Directory.CreateDirectory(dir);
			SweepStale(dir);
			var name = FitName(SanitiseName(displayName));
			var n = 1;
			var dest = Candidate(dir, name, n);
			while (File.Exists(dest) || Directory.Exists(dest)) {
				if (size >= 0 && File.Exists(dest) && new FileInfo(dest).Length == size) {
					return Path.GetFullPath(dest);
				}
				n++;
				dest = Candidate(dir, name, n);
			}

			// Written to a temporary and renamed, so a half-written book is never left under a
			// name the app will try to open.
			part = dest + PartSuffix;
			var input = open.Invoke();
			if (input == null) {
				throw new IOException("Could not read the picked file");
			}
			var target = part;
			Scope.run(input, () -> {
				var output:Stream = cast File.Create(target);
				Scope.run(output, () -> {
					input.CopyTo(output);
					// A provider can end the stream early without an error. Only short counts:
					// a size that is merely stale still gave a whole book.
					if (output.Length < size) {
						throw new IOException("The picked file ended early");
					}
				});
			});
			File.Move(part, dest);
			return Path.GetFullPath(dest);
		} catch (e:IOException) {
			if (part != null) {
				TryDelete(part);
			}
			throw e;
		} catch (e:Exception) {
			if (part != null) {
				TryDelete(part);
			}
			throw new IOException(e.Message, e);
		}
	}

	/**
	 * Import from bytes. `knownSize` false imports as a provider that reports no size does;
	 * `failAfter` (-1: never) makes the read fail after that many bytes, as a provider can.
	 */
	public static function ImportBytes(dir:String, displayName:String, bytes:NativeArray<UInt8>, knownSize:Bool, failAfter:Int):String {
		var open:Func_1<Stream> = function():Stream {
			return new FailingStream(bytes, failAfter);
		};
		return Import(dir, displayName, knownSize ? bytes.Length : -1, open);
	}

	/** Import of a document that reports its whole size and ends without an error after `endAfter` bytes. */
	public static function ImportCut(dir:String, displayName:String, bytes:NativeArray<UInt8>, endAfter:Int):String {
		var open:Func_1<Stream> = function():Stream {
			return new MemoryStream(bytes, 0, endAfter, true);
		};
		return Import(dir, displayName, bytes.Length, open);
	}

	/** A provider's display name is not a filename: it can be absent, and it can contain separators. */
	static function SanitiseName(displayName:String):String {
		var trimmed = StringTools.trim(displayName == null ? "" : displayName);
		var cleaned = StringTools.replace(StringTools.replace(trimmed, "/", "_"), "\\", "_");
		return cleaned == "" || cleaned == "." || cleaned == ".." ? "picked-" + Math.ffloor(Date.now().getTime()) : cleaned;
	}

	/**
	 * A name that fits, with its extension kept and no character split. Cut the same way each
	 * time, so the same book picked again still finds its copy.
	 */
	static function FitName(name:String):String {
		var utf8 = Encoding.UTF8;
		if (utf8.GetByteCount(name) <= MaxNameBytes) {
			return name;
		}
		var dot = name.lastIndexOf(".");
		var ext = dot > 0 && utf8.GetByteCount(name.substr(dot)) <= MaxExtensionBytes ? name.substr(dot) : "";
		var room = MaxNameBytes - utf8.GetByteCount(ext);
		var used = 0;
		var end = 0;
		while (end < name.length) {
			var unit:Int = name.charCodeAt(end);
			var next:Int = end + 1 < name.length ? name.charCodeAt(end + 1) : 0;
			var pair = unit >= 0xD800 && unit < 0xDC00 && next >= 0xDC00 && next < 0xE000;
			// UTF-8's length; a surrogate alone is written as U+FFFD, which is three bytes.
			var bytes = pair ? 4 : unit < 0x80 ? 1 : unit < 0x800 ? 2 : 3;
			if (used + bytes > room) {
				break;
			}
			used += bytes;
			end += pair ? 2 : 1;
		}
		return StringTools.rtrim(name.substring(0, end)) + ext;
	}

	/**
	 * A process killed during a copy leaves its temporary behind, and nothing picks that name
	 * again. Old ones only: a slow copy from before this pick may still be running.
	 */
	static function SweepStale(dir:String):Void {
		var cutoff = DateTime.UtcNow.AddHours(-1);
		var files = Directory.GetFiles(dir, "*" + PartSuffix);
		for (i in 0...files.Length) {
			if (DateTime.Compare(File.GetLastWriteTimeUtc(files[i]), cutoff) < 0) {
				TryDelete(files[i]);
			}
		}
	}

	/** `Book.epub` for 1, `Book (2).epub` for 2, ... A leading dot is not an extension. */
	static function Candidate(dir:String, name:String, n:Int):String {
		if (n <= 1) {
			return Path.Combine(dir, name);
		}
		var dot = name.lastIndexOf(".");
		var stem = dot > 0 ? name.substring(0, dot) : name;
		var ext = dot > 0 ? name.substr(dot) : "";
		return Path.Combine(dir, stem + " (" + n + ")" + ext);
	}

	static function TryDelete(path:String):Void {
		try {
			File.Delete(path);
		} catch (e:Dynamic) {}
	}
}

/** A stream that fails partway, as a provider can. Stream.CopyTo reads it through this overload. */
@:native("HaxeUICs.FailingStream")
@:nativeGen
class FailingStream extends MemoryStream {
	final _failAfter:Int;

	public function new(bytes:NativeArray<UInt8>, failAfter:Int) {
		super(bytes, false);
		_failAfter = failAfter;
	}

	@:overload
	override public function Read(buffer:NativeArray<UInt8>, offset:Int, count:Int):Int {
		if (_failAfter >= 0) {
			if (Position >= _failAfter) {
				throw new IOException("The picked file stopped reading");
			}
			var left:Int = cast(_failAfter - Position);
			if (left < count) {
				count = left;
			}
		}
		return super.Read(buffer, offset, count);
	}
}
