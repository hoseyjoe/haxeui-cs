package cases;

import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** HaxeUI styles painted by the native panel, checked on rendered pixels. **/
class TestStyles extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testBackgroundColor() {
		show("background-color: #FF0000;");
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
	}

	function testVerticalGradient() {
		show("background-color: #000000; background-color-end: #FFFFFF; background-gradient-style: vertical;");
		Assert.isTrue(brightness(TestDriver.pixel(50, 3)) < brightness(TestDriver.pixel(50, 56)));
	}

	function testBorderPerSide() {
		show("background-color: #FF0000; border-left-size: 4px; border-left-color: #00FF00;");
		Assert.equals(0xFF00FF00, TestDriver.pixel(1, 30));
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
	}

	function testPerSideBorderFollowsRadius() {
		show("background-color: #FFFFFF; border-radius: 12px; border-top-size: 4px; border-top-color: #FF0000;"
			+ " border-bottom-size: 4px; border-bottom-color: #0000FF; border-left-size: 1px; border-left-color: #000000;");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(1, 1), "outside the rounded corner");
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 1), "top side");
		Assert.equals(0xFF0000FF, TestDriver.pixel(50, 58), "bottom side");
		Assert.equals(0xFF000000, TestDriver.pixel(0, 30), "left side");
	}

	function testDashedBorderHasGaps() {
		show("background-color: #FFFFFF; border: 2px dashed #000000;");
		var row = TestDriver.pixels(4, 1, 92, 1);
		Assert.isTrue(Pixels.countWhere(row, p -> p == 0xFF000000) > 10, "dashes");
		Assert.isTrue(Pixels.countWhere(row, p -> Pixels.bright(p) > 700) > 10, "gaps");
	}

	function testDottedPerSideBorder() {
		show("background-color: #FFFFFF; border-left-size: 2px; border-left-color: #000000; border-style: dotted;");
		var col = TestDriver.pixels(1, 4, 1, 52);
		Assert.isTrue(Pixels.countWhere(col, p -> Pixels.bright(p) < 200) > 5, "dots");
		Assert.isTrue(Pixels.countWhere(col, p -> Pixels.bright(p) > 700) > 10, "gaps");
	}

	function testSolidBorderHasNoGaps() {
		show("background-color: #FFFFFF; border: 2px solid #000000;");
		Assert.equals(0, Pixels.countWhere(TestDriver.pixels(4, 1, 92, 1), p -> Pixels.bright(p) > 700));
	}

	function testBorderRadius() {
		show("background-color: #FF0000; border-radius: 20px;");
		Assert.notEquals(0xFFFF0000, TestDriver.pixel(1, 1));
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
	}

	function testOpacity() {
		show("background-color: #000000; opacity: 0.5;");
		var p = TestDriver.pixel(50, 30);
		for (channel in [(p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF]) {
			Assert.isTrue(Math.abs(channel - 0x7F) <= 3, 'channel $channel of ${StringTools.hex(p, 8)}');
		}
	}

	function testCaptureStyledPanels() {
		var styles = [
			"background-color: #3C8DDE; border-radius: 8px;",
			"background-color: #222222; background-color-end: #888888; border-size: 2px; border-color: #FFCC00;",
			"background-color: #FFFFFF; border-left-size: 6px; border-left-color: #E04040; border-bottom-size: 2px; border-bottom-color: #4040E0;",
			"background-color: #40A040; opacity: 0.4; border-radius: 30px;",
		];
		var x = 10;
		for (s in styles) {
			var box = new Box();
			box.left = x;
			box.top = 10;
			box.width = 120;
			box.height = 80;
			box.styleString = "padding: 0px; " + s;
			Screen.instance.addComponent(box);
			x += 135;
		}
		TestDriver.pump(2);
		TestDriver.capture("tests/bin/styles.png");
		Assert.isTrue(sys.FileSystem.exists("tests/bin/styles.png"));
	}

	static function show(styleString:String):Box {
		var box = new Box();
		box.width = 100;
		box.height = 60;
		box.styleString = "border-size: 0px; padding: 0px; " + styleString;
		Screen.instance.addComponent(box);
		TestDriver.pump(2);
		return box;
	}

	static function brightness(argb:Int):Int {
		return ((argb >> 16) & 0xFF) + ((argb >> 8) & 0xFF) + (argb & 0xFF);
	}
}
