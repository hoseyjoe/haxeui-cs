package cases;

import haxe.ui.backend.cs.TestDriver;
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
