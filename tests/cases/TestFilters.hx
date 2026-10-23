package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.components.Label;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import utest.Assert;
import cases.Pixels.bright;

/**
 * CSS filters as html5 draws them (haxe/ui/backend/html5/FilterHelper.hx): shadows shadow the
 * component's box. Each test's box is white on the white window, so any darker pixel is shadow.
 */
class TestFilters extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testDropShadowOffsetsDownRight() {
		// html5: offset (distance, distance + 2), blur blurX - 1 (here 0)
		box("filter: drop-shadow(4, 45, #000000, 0.5, 1, 1, 1, 1, false);");
		Assert.isTrue(bright(TestDriver.pixel(122, 84)) < 520, "inside the shadow, outside the box");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(16, 50), "no shadow on the left");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(122, 23), "the shadow starts 6px down");
	}

	function testInnerDropShadow() {
		box("filter: drop-shadow(4, 45, #000000, 0.8, 2, 1, 1, 1, true);");
		Assert.isTrue(bright(TestDriver.pixel(22, 22)) < bright(TestDriver.pixel(70, 50)));
	}

	function testBoxShadowAsWritten() {
		box("filter: box-shadow(-6, 0, #000000, 0.5, 0, 0, false);");
		Assert.isTrue(bright(TestDriver.pixel(16, 50)) < 520);
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(123, 50));
	}

	function testShadowClears() {
		var b = box("filter: box-shadow(-6, 0, #000000, 0.5, 0, 0, false);");
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; filter: none;";
		TestDriver.pump(3);
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(16, 50));
	}

	function testThemePopupHasAShadow() {
		var b = box("");
		b.addClass("popup");
		TestDriver.pump(3);
		Assert.isTrue(bright(TestDriver.pixel(70, 83)) < 765, "the theme's .popup drop-shadow shows below the box");
	}

	// text-shadow (a haxeui-cs directive): white glyphs on the white window are invisible,
	// so every dark pixel is shadow.

	function testTextShadowDrawsBehindGlyphs() {
		var l = whiteLabel("text-shadow: 2px 2px 0px #000000;");
		Assert.isTrue(Pixels.countWhere(around(l), p -> bright(p) < 200) > 20);
	}

	function testTextShadowAlpha() {
		var l = whiteLabel("text-shadow: 2px 2px 0px #000000 0.5;");
		var px = around(l);
		Assert.equals(0, Pixels.countWhere(px, p -> bright(p) < 250), "half-alpha black is never near-black");
		Assert.isTrue(Pixels.countWhere(px, p -> bright(p) < 520) > 20);
	}

	function testTextShadowNone() {
		var l = whiteLabel("text-shadow: 2px 2px 0px #000000;");
		l.styleString = "font-size: 24px; color: #FFFFFF; text-shadow: none;";
		TestDriver.pump(3);
		Assert.equals(0, Pixels.countWhere(around(l), p -> bright(p) < 700));
	}

	function testShadowSetBeforeText() {
		var l = new Label();
		l.left = 10;
		l.top = 10;
		l.styleString = "font-size: 24px; color: #FFFFFF; text-shadow: 2px 2px 0px #000000;";
		Screen.instance.addComponent(l);
		TestDriver.pump(2);
		l.text = "MMMM";
		TestDriver.pump(3);
		Assert.isTrue(Pixels.countWhere(around(l), p -> bright(p) < 200) > 20);
	}

	static function whiteLabel(style:String):Label {
		var l = new Label();
		l.left = 10;
		l.top = 10;
		l.text = "MMMM";
		l.styleString = "font-size: 24px; color: #FFFFFF; " + style;
		Screen.instance.addComponent(l);
		TestDriver.pump(3);
		return l;
	}

	static function around(l:Label):Array<Int> {
		return TestDriver.pixels(10, 10, Std.int(l.width) + 4, Std.int(l.height) + 4);
	}

	static function box(style:String):Box {
		var b = new Box();
		b.left = 20;
		b.top = 20;
		b.width = 100;
		b.height = 60;
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; " + style;
		Screen.instance.addComponent(b);
		TestDriver.pump(3);
		return b;
	}
}
