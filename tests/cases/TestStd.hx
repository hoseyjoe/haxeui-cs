package cases;

import utest.Assert;

/**
 * Haxe's own std, run on .NET, answering as it does on every other target.
 * Haxe 4.3's C# StringTools.startsWith / endsWith call .NET's culture-aware
 * StartsWith / EndsWith, to which a BOM or a soft hyphen is "ignorable": every
 * string started and ended with one, so the usual BOM strip cut off a real "<".
 */
class TestStd extends utest.Test {
	static var BOM = String.fromCharCode(0xFEFF);
	static var SOFT_HYPHEN = String.fromCharCode(0xAD);

	function testStartsWithIsOrdinal() {
		Assert.isFalse(StringTools.startsWith("<svg>", BOM));
		Assert.isFalse(StringTools.startsWith("<svg>", SOFT_HYPHEN));
		Assert.isTrue(StringTools.startsWith(BOM + "<svg>", BOM));
		Assert.isTrue(StringTools.startsWith("<svg>", "<sv"));
		Assert.isTrue(StringTools.startsWith("<svg>", ""));
		Assert.isFalse(StringTools.startsWith("<s", "<svg>"));
	}

	function testEndsWithIsOrdinal() {
		Assert.isFalse(StringTools.endsWith("</svg>", BOM));
		Assert.isFalse(StringTools.endsWith("</svg>", SOFT_HYPHEN));
		Assert.isTrue(StringTools.endsWith("</svg>" + SOFT_HYPHEN, SOFT_HYPHEN));
		Assert.isTrue(StringTools.endsWith("</svg>", "vg>"));
		Assert.isTrue(StringTools.endsWith("</svg>", ""));
		Assert.isFalse(StringTools.endsWith("g>", "</svg>"));
	}

	/** Through Dynamic too: the call is not always inlined at a typed site. **/
	function testThroughAFunctionValue() {
		var startsWith:(String, String) -> Bool = StringTools.startsWith;
		var endsWith:(String, String) -> Bool = StringTools.endsWith;
		Assert.isFalse(startsWith("<svg>", BOM));
		Assert.isFalse(endsWith("</svg>", BOM));
	}

	/**
	 * A generic class's instance reaching a generic interface it implements, with
	 * another parameter: thenshim's `Promise<Bool>` handed back from a `then`.
	 * Haxe's C# cast forwarder passes the wrong parameter (GenericInterfaceCast).
	 */
	function testGenericInterfaceCast() {
		var value:Any = new CastBox<Bool>(true);
		Assert.isTrue((value is ICastBox));
		Assert.equals(true, unbox(value));
	}

	static function unbox(box:ICastBox<Any>):Any {
		return box.get();
	}

	// One text deflated by Python's zlib four ways: raw (a zip entry's body), zlib, gzip, and a
	// whole zip holding it as a.txt. Haxe 4.3's C# std has no Uncompress at all (NativeUncompress).
	static var TEXT = [for (_ in 0...12) "haxeui-cs inflates this. "].join("") + "The end.";
	static inline var RAW = "y0isSC3N1E0uVsjMS8tJLEktVijJyCzWU8gYlUCXCMlIVUjNS9EDAA==";
	static inline var ZLIB = "eNrLSKxILc3UTS5WyMxLy0ksSS1WKMnILNZTyBiVQJcIyUhVSM1L0QMAL8xwSw==";
	static inline var GZIP = "H4sIAAAAAAAC/8tIrEgtzdRNLlbIzEvLSSxJLVYoycgs1lPIGJVAlwjJSFVIzUvRAwDL/b/LNAEAAA==";
	static inline var ZIP = "UEsDBBQAAAAIAI+1XF3L/b/LKAAAADQBAAAFAAAAYS50eHTLSKxILc3UTS5WyMxLy0ksSS1WKMnILNZTyBiVQJcIyUhVSM1L0QMAUEsBAhQAFAAAAAgAj7VcXcv9v8soAAAANAEAAAUAAAAAAAAAAAAAAIABAAAAAGEudHh0UEsFBgAAAAABAAEAMwAAAEsAAAAAAA==";

	function testUnzipAnEntry() {
		var entries = haxe.zip.Reader.readZip(new haxe.io.BytesInput(haxe.crypto.Base64.decode(ZIP)));
		Assert.equals(1, entries.length);
		var entry = entries.first();
		Assert.isTrue(entry.compressed);
		Assert.equals(TEXT, haxe.zip.Reader.unzip(entry).toString());
	}

	function testUncompressRunReadsZlib() {
		Assert.equals(TEXT, haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(ZLIB)).toString());
	}

	function testWindowBitsPickTheFormat() {
		Assert.equals(TEXT, uncompress(RAW, -15));
		Assert.equals(TEXT, uncompress(ZLIB, 15));
		Assert.equals(TEXT, uncompress(ZLIB, null));
		Assert.equals(TEXT, uncompress(GZIP, 31));
		Assert.equals(TEXT, uncompress(GZIP, 47));
		Assert.equals(TEXT, uncompress(ZLIB, 47));
	}

	/** Output larger than dst comes out over several calls, the input read once. **/
	function testSmallDestinationDrainsOverCalls() {
		var src = haxe.crypto.Base64.decode(RAW);
		var u = new haxe.zip.Uncompress(-15);
		var dst = haxe.io.Bytes.alloc(100);
		var out = new haxe.io.BytesBuffer();
		var srcPos = 0;
		var calls = 0;
		while (true) {
			var r = u.execute(src, srcPos, dst, 0);
			srcPos += r.read;
			out.addBytes(dst, 0, r.write);
			calls++;
			if (r.done || calls > 10) break;
		}
		u.close();
		Assert.equals(4, calls);
		Assert.equals(src.length, srcPos);
		Assert.equals(TEXT, out.getBytes().toString());
	}

	function testCorruptInputThrows() {
		var bad = haxe.io.Bytes.ofString("not deflate at all");
		Assert.raises(() -> haxe.zip.Uncompress.run(bad));
	}

	static function uncompress(base64:String, windowBits:Null<Int>):String {
		var src = haxe.crypto.Base64.decode(base64);
		var u = new haxe.zip.Uncompress(windowBits);
		var dst = haxe.io.Bytes.alloc(TEXT.length);
		var r = u.execute(src, 0, dst, 0);
		u.close();
		return r.done && r.read == src.length && r.write == TEXT.length ? dst.toString() : null;
	}
}

private interface ICastBox<T> {
	function get():T;
}

private class CastBox<T> implements ICastBox<T> {
	var value:T;

	public function new(value:T) {
		this.value = value;
	}

	public function get():T {
		return value;
	}
}
