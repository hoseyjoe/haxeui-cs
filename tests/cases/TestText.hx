package cases;

import haxe.ui.components.Label;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Text display: measuring, wrapping, font styling and rendering. **/
class TestText extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testLabelMeasures() {
		var label = show("Hello");
		Assert.isTrue(label.width > 20, 'width ${label.width}');
		Assert.isTrue(label.height >= 10 && label.height <= 40, 'height ${label.height}');
	}

	function testWordWrapGrowsHeight() {
		var single = show("Hello");
		var wrapped = new Label();
		wrapped.text = "the quick brown fox jumps over a lazy dog";
		wrapped.wordWrap = true;
		wrapped.width = 60;
		wrapped.top = 100;
		Screen.instance.addComponent(wrapped);
		TestDriver.pump(2);
		Assert.isTrue(wrapped.height > 2 * single.height, 'wrapped ${wrapped.height} vs line ${single.height}');
	}

	function testFontStyleApplied() {
		var label = show("Bold", "font-size: 24px; font-bold: true;");
		var native = label.getTextDisplay().textNative;
		Assert.equals(24.0, native.FontSize);
		Assert.isTrue(native.IsBold);
	}

	function testTextColorRenders() {
		var label = show("Bright text", "color: #FFFFFF; background-color: #000000; font-size: 20px;");
		var lightest = 0;
		for (y in 0...Std.int(label.height)) {
			for (x in 0...Std.int(label.width)) {
				var p = TestDriver.pixel(x, y) & 0xFF;
				if (p > lightest) lightest = p;
			}
			if (lightest > 0x80) break;
		}
		Assert.isTrue(lightest > 0x80, 'lightest channel ${lightest}');
	}

	function testUnicodeLabel() {
		var text = "Café — “quoted”";
		var label = show(text);
		Assert.equals(text, label.getTextDisplay().textNative.Text);
	}

	static function show(text:String, ?styleString:String):Label {
		var label = new Label();
		label.text = text;
		if (styleString != null) {
			label.styleString = styleString;
		}
		Screen.instance.addComponent(label);
		TestDriver.pump(2);
		return label;
	}
}
