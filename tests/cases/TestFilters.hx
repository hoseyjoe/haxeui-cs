package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.components.Canvas;
import haxe.ui.components.Image;
import haxe.ui.components.Label;
import haxe.ui.containers.Absolute;
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

	function testBlurSoftensEdges() {
		edge("filter: blur(4);");
		var b = bright(TestDriver.pixel(20 + 42, 50));
		Assert.isTrue(b > 60 && b < 720, 'grey expected next to the black stripe, got $b');
	}

	function testBlurClears() {
		var parent = edge("filter: blur(4);");
		parent.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; filter: none;";
		TestDriver.pump(3);
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(20 + 42, 50));
	}

	/** A white box at (20, 20) holding a black 10px stripe at x 45..55 of it. **/
	static function edge(style:String):Box {
		var stripe = new Box();
		stripe.left = 45;
		stripe.top = 0;
		stripe.width = 10;
		stripe.height = 60;
		stripe.styleString = "border-size: 0px; padding: 0px; background-color: #000000;";
		var parent = new haxe.ui.containers.Absolute();
		parent.left = 20;
		parent.top = 20;
		parent.width = 100;
		parent.height = 60;
		parent.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; " + style;
		parent.addComponent(stripe);
		Screen.instance.addComponent(parent);
		TestDriver.pump(3);
		return cast parent;
	}

	// Colour filters, as CSS filter functions (html5): expected values worked out by hand.

	function testGrayscale() {
		var p = solid("#FF0000", "grayscale");
		Assert.isTrue(near(p, gray(p), 3), StringTools.hex(p, 8));
	}

	function testBrightnessHalves() {
		var p = solid("#C86432", "brightness(0.5)");
		Assert.isTrue(near(p, 0xFF643219, 2), StringTools.hex(p, 8));
	}

	function testInvert() {
		var p = solid("#FF0000", "invert(1)");
		Assert.isTrue(near(p, 0xFF00FFFF, 2), StringTools.hex(p, 8));
	}

	function testSaturateZeroIsGray() {
		var p = solid("#3366CC", "saturate(0)");
		Assert.isTrue(near(p, gray(p), 3), StringTools.hex(p, 8));
	}

	function testContrastZeroIsMidGray() {
		var p = solid("#3366CC", "contrast(0)");
		Assert.isTrue(near(p, 0xFF808080, 3), StringTools.hex(p, 8));
	}

	function testHueRotate180TurnsRedTowardsCyan() {
		var p = solid("#FF0000", "hue-rotate(180)");
		var r = (p >> 16) & 0xFF, g = (p >> 8) & 0xFF, b = p & 0xFF;
		Assert.isTrue(r < g && r < b, StringTools.hex(p, 8));
	}

	function testTint() {
		var p = solid("#FFFFFF", "tint(#FF0000, 1)");
		Assert.isTrue(near(p, 0xFFFF0000, 6), StringTools.hex(p, 8));
	}

	function testFilterReachesChildren() {
		var parent = new Absolute();
		parent.left = 20;
		parent.top = 20;
		parent.width = 60;
		parent.height = 40;
		parent.styleString = "filter: grayscale;";
		var child = new Box();
		child.width = 60;
		child.height = 40;
		child.styleString = "border-size: 0px; padding: 0px; background-color: #FF0000;";
		parent.addComponent(child);
		Screen.instance.addComponent(parent);
		TestDriver.pump(3);
		var p = TestDriver.pixel(40, 40);
		Assert.isTrue(near(p, gray(p), 3), StringTools.hex(p, 8));
	}

	function testFilterReachesImageAndCanvas() {
		var parent = new Absolute();
		parent.left = 20;
		parent.top = 20;
		parent.width = 120;
		parent.height = 40;
		parent.styleString = "filter: grayscale;";
		var image = new Image();
		image.resource = "red4x4.png";
		image.width = 40;
		image.height = 40;
		parent.addComponent(image);
		var canvas = new Canvas();
		canvas.left = 60;
		canvas.width = 40;
		canvas.height = 40;
		parent.addComponent(canvas);
		Screen.instance.addComponent(parent);
		TestDriver.pump(3);
		canvas.componentGraphics.fillStyle(0xFF0000);
		canvas.componentGraphics.rectangle(0, 0, 40, 40);
		canvas.componentGraphics.fillStyle(null);
		TestDriver.pump(3);
		var fromImage = TestDriver.pixel(40, 40);
		var fromCanvas = TestDriver.pixel(100, 40);
		Assert.isTrue(near(fromImage, gray(fromImage), 3) && bright(fromImage) < 600, 'image ${StringTools.hex(fromImage, 8)}');
		Assert.isTrue(near(fromCanvas, gray(fromCanvas), 3) && bright(fromCanvas) < 600, 'canvas ${StringTools.hex(fromCanvas, 8)}');
	}

	function testSetPixelUnderColourFilter() {
		// each new pixel shows through the filter, not just the first
		var parent = new Absolute();
		parent.width = 40;
		parent.height = 40;
		parent.styleString = "filter: grayscale;";
		var canvas = new Canvas();
		canvas.width = 40;
		canvas.height = 40;
		parent.addComponent(canvas);
		Screen.instance.addComponent(parent);
		TestDriver.pump(3);
		canvas.componentGraphics.setPixel(5, 5, 0xFF0000);
		TestDriver.pump(3);
		Assert.isTrue(bright(TestDriver.pixel(5, 5)) < 600, "the first pixel, filtered");
		canvas.componentGraphics.setPixel(10, 5, 0xFF0000);
		TestDriver.pump(3);
		var p = TestDriver.pixel(10, 5);
		Assert.isTrue(bright(p) < 600 && near(p, gray(p), 3), 'the second pixel: ${StringTools.hex(p, 8)}');
	}

	function testColourFilterClears() {
		var b = box("background-color: #FF0000; filter: grayscale;");
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FF0000; filter: none;";
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(70, 50));
	}

	function testDisabledImageIsGray() {
		// the default theme: .image:disabled { filter: grayscale }
		var image = new Image();
		image.resource = "red4x4.png";
		image.width = 40;
		image.height = 40;
		Screen.instance.addComponent(image);
		TestDriver.pump(3);
		image.disabled = true;
		TestDriver.pump(3);
		var p = TestDriver.pixel(20, 20);
		Assert.isTrue(near(p, gray(p), 3) && bright(p) < 600, StringTools.hex(p, 8));
	}

	static function solid(colour:String, filter:String):Int {
		var b = new Box();
		b.left = 20;
		b.top = 20;
		b.width = 60;
		b.height = 40;
		b.styleString = 'border-size: 0px; padding: 0px; background-color: $colour; filter: $filter;';
		Screen.instance.addComponent(b);
		TestDriver.pump(3);
		return TestDriver.pixel(40, 40);
	}

	static function near(a:Int, b:Int, tolerance:Int):Bool {
		for (shift in [16, 8, 0]) {
			if (Math.abs(((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)) > tolerance) {
				return false;
			}
		}
		return true;
	}

	/** The opaque grey whose three channels are a pixel's channel average. **/
	static function gray(p:Int):Int {
		var avg = Math.round((((p >> 16) & 0xFF) + ((p >> 8) & 0xFF) + (p & 0xFF)) / 3);
		return 0xFF000000 | (avg << 16) | (avg << 8) | avg;
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
