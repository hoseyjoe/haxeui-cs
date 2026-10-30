package cases;

import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.TextLinkEvent;
import haxe.ui.backend.cs.native.Native.UIText;
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

	function testHtmlFontColour() {
		var l = html('<font color="#FF0000">RED</font>', "font-size: 24px; color: #000000;");
		var px = TestDriver.pixels(Std.int(l.screenLeft), Std.int(l.screenTop), Std.int(l.width), Std.int(l.height));
		var red = Pixels.countWhere(px, p -> ((p >> 16) & 0xFF) > 200 && ((p >> 8) & 0xFF) < 60 && (p & 0xFF) < 60);
		Assert.isTrue(red > 10, 'red pixels: $red');
	}

	function testHtmlBold() {
		var plain = html("WWWW").width;
		var bold = html("<b>WWWW</b>").width;
		Assert.isTrue(bold > plain, 'bold $bold, plain $plain');
	}

	function testHtmlLineBreak() {
		var one = html("one").height;
		var two = html("one<br>two").height;
		Assert.isTrue(two >= 1.8 * one, 'one line $one, two lines $two');
	}

	function testHtmlUnknownTagKeepsText() {
		Assert.floatEquals(html("x").width, html("<blink>x</blink>").width, 0.5);
	}

	function testHtmlEntities() {
		var plain = show("a & b").width;
		Assert.floatEquals(plain, html("a &amp; b").width, 0.5);
	}

	function testHtmlLinks() {
		var l = html('Read <a href="one.html">the first</a> and <a href="two?a=1&amp;b=2">the second</a>.');
		var text = l.getTextDisplay();
		Assert.equals(2, text.linkCount());
		Assert.equals("one.html", text.linkHref(0));
		Assert.equals("two?a=1&b=2", text.linkHref(1));
		Assert.isNull(text.linkHref(2));
		Assert.equals("Read the first and the second.", (cs.Syntax.code("{0}.Inlines.Text", text.textNative) : String), "the anchors' text is kept");
	}

	function testHtmlAnchorWithoutHrefIsText() {
		var l = html('<a name="here">anchor</a>');
		Assert.equals(0, l.getTextDisplay().linkCount());
	}

	function testLinkRectsAndHitTest() {
		var l = html('Read <a href="x">the first</a> now', "font-size: 20px;");
		var text = l.getTextDisplay();
		var rects = text.linkRects();
		Assert.equals(1, rects.length);
		var r = rects[0];
		Assert.equals(0, r.index);
		Assert.isTrue(r.left > 20 && r.left + r.width < l.width - 20, 'link at ${r.left}..${r.left + r.width} of ${l.width}');
		Assert.equals(0, text.linkAt(r.left + r.width / 2, r.top + r.height / 2));
		Assert.equals(-1, text.linkAt(2, r.top + r.height / 2), "on Read");
		Assert.equals(-1, text.linkAt(l.width - 2, r.top + r.height / 2), "on now");
	}

	/** Each br counts in the text the link ranges index: a link after one starts its line. **/
	function testLinkAfterLineBreaks() {
		var l = html('one<br>two<br><a href="x">three</a> four', "font-size: 20px;");
		var r = l.getTextDisplay().linkRects()[0];
		Assert.isTrue(r.left < 2, 'starts its line: ${r.left}');
		Assert.isTrue(r.top > l.height / 2, 'on the third line: ${r.top} of ${l.height}');
		var three = html("three", "font-size: 20px;").width;
		Assert.floatEquals(three, r.width, 3, 'covers "three": ${r.width} vs $three');
	}

	function testLinkBrokenOverLinesHasARectEach() {
		var l = new Label();
		l.htmlText = 'x <a href="long">one two three four five six seven eight</a>';
		l.wordWrap = true;
		l.width = 120;
		Screen.instance.addComponent(l);
		TestDriver.pump(3);
		var rects = l.getTextDisplay().linkRects();
		Assert.isTrue(rects.length >= 2, '${rects.length} rects');
		for (r in rects) {
			Assert.equals(0, r.index);
			Assert.isTrue(r.left + r.width <= 121, 'inside the width: ${r.left + r.width}');
		}
	}

	function testLinkClickDispatchesTextLinkEvent() {
		var l = html('Go <a href="target">there</a> now', "font-size: 20px;");
		var got:Array<String> = [];
		l.registerEvent(TextLinkEvent.LINK, e -> got.push(e.href + "#" + e.index));
		var r = l.getTextDisplay().linkRects()[0];
		TestDriver.click(l.screenLeft + 3, l.screenTop + r.top + r.height / 2);
		Assert.equals(0, got.length, "a click off the link");
		TestDriver.click(l.screenLeft + r.left + r.width / 2, l.screenTop + r.top + r.height / 2);
		Assert.same(["target#0"], got);
	}

	function testLinkShowsAHand() {
		var l = html('Go <a href="target">there</a> now', "font-size: 20px;");
		var r = l.getTextDisplay().linkRects()[0];
		var y = l.screenTop + r.top + r.height / 2;
		TestDriver.mouseMove(l.screenLeft + r.left + r.width / 2, y);
		Assert.isTrue(cs.Syntax.code("{0}.Cursor != null", l.nativePanel), "a hand over the link");
		TestDriver.mouseMove(l.screenLeft + 3, y);
		Assert.isTrue(cs.Syntax.code("{0}.Cursor == null", l.nativePanel), "the label's own (none) beside it");
	}

	function testPlainTextAfterHtmlHasNoLinks() {
		var l = html('<a href="x">link</a>');
		l.text = "plain";
		TestDriver.pump(2);
		Assert.equals(0, l.getTextDisplay().linkCount());
		Assert.equals(0, l.getTextDisplay().linkRects().length);
	}

	function testLineBoxes() {
		var l = new Label();
		l.text = "the quick brown fox jumps over a lazy dog and on";
		l.wordWrap = true;
		l.width = 80;
		l.styleString = "font-size: 16px;";
		Screen.instance.addComponent(l);
		TestDriver.pump(3);
		var boxes = l.getTextDisplay().lineBoxes();
		Assert.isTrue(boxes.length >= 3, '${boxes.length} lines');
		var bottom = boxes[0].top;
		for (b in boxes) {
			Assert.floatEquals(bottom, b.top, 0.01, "each line starts where the last ended");
			Assert.isTrue(b.height > 10 && b.height < 30, 'height ${b.height}');
			bottom = b.top + b.height;
		}
		Assert.floatEquals(l.getTextDisplay().textHeight, bottom - boxes[0].top, 1.5);
	}

	function testLineHeightDirective() {
		var normal = lines("font-size: 20px;");
		var doubled = lines("font-size: 20px; line-height: 2;");
		var px = lines("font-size: 20px; line-height: 31px;");
		var percent = lines("font-size: 20px; line-height: 150%;");
		Assert.equals(normal.boxes.length, doubled.boxes.length, "the same lines");
		for (b in doubled.boxes) Assert.floatEquals(40, b.height, 0.01);
		for (b in px.boxes) Assert.floatEquals(31, b.height, 0.01);
		for (b in percent.boxes) Assert.floatEquals(30, b.height, 0.01);
		Assert.isTrue(doubled.label.height > normal.label.height + 10, 'taller: ${doubled.label.height} vs ${normal.label.height}');
		var reset = lines("font-size: 20px; line-height: normal;");
		Assert.floatEquals(normal.boxes[0].height, reset.boxes[0].height, 0.01);
	}

	static inline var LONG = "the quick brown fox jumps over a lazy dog and on";

	static function measured(text:UIText, maxWidth:Float):{w:Float, h:Float} {
		text.MeasureText(maxWidth);
		return {w: text.MeasuredWidth, h: text.MeasuredHeight};
	}

	static function plainText(content:String, size:Float):UIText {
		var text = new UIText();
		text.SetWrap(true);
		text.SetFont(null, size, false, false, false, false);
		text.Text = content;
		return text;
	}

	function testMeasuringAgainDoesNotLayOutAgain() {
		var text = plainText(LONG, 16);
		var unbounded = measured(text, 0);
		var wrapped = measured(text, 80);
		var layouts = text.MeasureLayouts;
		for (_ in 0...3) {
			var u = measured(text, 0);
			var w = measured(text, 80);
			Assert.equals(unbounded.w, u.w);
			Assert.equals(unbounded.h, u.h);
			Assert.equals(wrapped.w, w.w);
			Assert.equals(wrapped.h, w.h);
		}
		Assert.equals(layouts, text.MeasureLayouts, "the same text at the same widths is only laid out once each");
		Assert.isTrue(wrapped.h > unbounded.h, 'wrapped ${wrapped.h} vs one line ${unbounded.h}');
	}

	function testAColourAndABoxDoNotMeasureAgain() {
		var text = plainText(LONG, 16);
		measured(text, 80);
		var layouts = text.MeasureLayouts;
		text.SetColor(0xFF112233);
		text.SetBounds(5, 6, 200, 300);
		measured(text, 80);
		Assert.equals(layouts, text.MeasureLayouts);
	}

	function testMeasuringFollowsWhatTheTextIs() {
		var text = plainText(LONG, 16);
		measured(text, 80);

		// A new width, text, size, wrap, line height or HTML each answer as a new text would.
		Assert.same(measured(plainText(LONG, 16), 200), measured(text, 200), "width");
		text.Text = "short";
		Assert.same(measured(plainText("short", 16), 80), measured(text, 80), "text");
		text.Text = LONG;
		text.SetFont(null, 30, false, false, false, false);
		Assert.same(measured(plainText(LONG, 30), 80), measured(text, 80), "size");

		var noWrap = plainText(LONG, 30);
		noWrap.SetWrap(false);
		text.SetWrap(false);
		Assert.same(measured(noWrap, 80), measured(text, 80), "wrap");
		text.SetWrap(true);

		var tall = plainText(LONG, 30);
		tall.SetLineHeight(60);
		text.SetLineHeight(60);
		Assert.same(measured(tall, 80), measured(text, 80), "line height");
		text.SetLineHeight(0);

		var one = plainText(LONG, 30);
		one.SetHtml("one<br>two");
		var other = plainText(LONG, 30);
		other.SetHtml("one<br>two<br>three<br>four");
		text.SetHtml("one<br>two");
		Assert.same(measured(one, 80), measured(text, 80), "html");
		text.SetHtml("one<br>two<br>three<br>four");
		Assert.same(measured(other, 80), measured(text, 80), "other html");
	}

	function testAnEmptyTextIsOneLineTallAndNoneWide() {
		var text = plainText("", 16);
		var empty = measured(text, 0);
		Assert.equals(0.0, empty.w);
		Assert.isTrue(empty.h > 10, 'height ${empty.h}');
		Assert.equals("", text.Text);
		Assert.same(empty, measured(text, 0));
		text.Text = "words";
		Assert.isTrue(measured(text, 0).w > 10);
	}

	function testLinesAndLinksAfterAMeasureThatWasRemembered() {
		var label = html('<a href="a">the quick brown fox</a> jumps over a lazy dog', "font-size: 16px; width: 80px;");
		label.wordWrap = true;
		TestDriver.pump(3);
		var display = label.getTextDisplay();
		var lines = display.lineBoxes().length;
		var rects = display.linkRects().length;
		Assert.isTrue(lines >= 3, '$lines lines');
		var native = display.textNative;
		measured(native, 0);
		measured(native, 80);
		measured(native, 0);
		Assert.equals(lines, display.lineBoxes().length);
		Assert.equals(rects, display.linkRects().length);
	}

	static function lines(styleString:String):{label:Label, boxes:Array<{top:Float, height:Float}>} {
		var l = html("one<br>two<br>three", styleString);
		return {label: l, boxes: l.getTextDisplay().lineBoxes()};
	}

	static function html(markup:String, ?styleString:String):Label {
		var label = new Label();
		label.htmlText = markup;
		if (styleString != null) {
			label.styleString = styleString;
		}
		Screen.instance.addComponent(label);
		TestDriver.pump(3);
		return label;
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
