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
