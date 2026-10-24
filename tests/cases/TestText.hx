package cases;

import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.core.Component;
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

	function testStrikeThrough() {
		// "o" has no horizontal strokes of its own: only a line through it makes a long dark run
		var plain = show("oooooo", "font-size: 30px; color: #000000;");
		var plainRun = darkRun(plain);
		Screen.instance.removeComponent(plain);
		var struck = show("oooooo", "font-size: 30px; color: #000000; text-decoration: line-through;");
		Assert.isTrue(darkRun(struck) > 0.8 * struck.width, 'struck run ${darkRun(struck)} of ${struck.width}');
		Assert.isTrue(plainRun < 0.5 * plain.width, 'plain run $plainRun of ${plain.width}');
	}

	function testTextInputUnderline() {
		var f = new TextField();
		f.styleString = "font-size: 30px; color: #000000; font-underline: true; border-size: 0px; background-color: #FFFFFF;";
		f.text = "oooooo";
		Screen.instance.addComponent(f);
		TestDriver.pump(3);
		var run = darkRun(f);
		Assert.isTrue(run > 0.6 * f.getTextInput().textWidth, 'run $run of ${f.getTextInput().textWidth}');
	}

	function testJustify() {
		var label = new Label();
		label.width = 200;
		label.wordWrap = true;
		label.styleString = "font-size: 13px; color: #000000; text-align: justify;";
		label.text = "aa bb cc dd ee ff gg hh ii jj kk ll mm nn oo pp";
		Screen.instance.addComponent(label);
		TestDriver.pump(3);
		// the first line reaches the right edge; left-aligned, its end is ragged
		var px = TestDriver.pixels(0, 0, 200, 14);
		var rightmost = -1;
		for (row in 0...14) {
			for (x in 0...200) {
				if (Pixels.bright(px[row * 200 + x]) < 500 && x > rightmost) {
					rightmost = x;
				}
			}
		}
		Assert.isTrue(rightmost >= 196, 'first line ends at x $rightmost');
	}

	/** The longest run of dark pixels in any one row of the component. **/
	static function darkRun(c:Component):Int {
		var w = Std.int(c.width), h = Std.int(c.height);
		var px = TestDriver.pixels(Std.int(c.screenLeft), Std.int(c.screenTop), w, h);
		var best = 0;
		for (row in 0...h) {
			var run = Pixels.longestRun(px, w, row, p -> Pixels.bright(p) < 300);
			if (run > best) {
				best = run;
			}
		}
		return best;
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
