package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import utest.Assert;

/**
 * UIPanel.SetScale and SetAlpha: what a backend whose components are display
 * objects (haxeui-heaps' h2d scaleX/scaleY/alpha) asks of a panel, for a zoom
 * or a fade. Neither touches layout.
 */
class TestPanelTransform extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testScaleIsAboutTheTopLeft() {
		var b = red(100, 100, 100, 20, "");
		panel(b).SetScale(2, 2);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(290, 135), "the far corner, doubled");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(95, 105), "nothing grows left of the corner");
		Assert.equals(100., b.left, "layout is untouched");
		Assert.equals(100., b.width);
		panel(b).SetScale(1, 1);
		TestDriver.pump(3);
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(290, 135), "back to its own size");
	}

	function testScaleComposesWithRotation() {
		// turned a quarter about its centre (local 50, 10): local x 40..60, y -40..60;
		// then doubled about the top-left: x 80..120, y -80..120, so screen 180..220 by 20..220
		var b = red(100, 100, 100, 20, "rotation: 90;");
		panel(b).SetScale(2, 2);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(200, 210), "near the turned bar's far end, doubled");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(150, 110), "the old centre is outside it now");
		panel(b).SetScale(1, 1);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(150, 140), "still turned once the scale is gone");
	}

	function testAlphaMultipliesStyleOpacity() {
		var b = red(0, 0, 100, 60, "opacity: 0.5;");
		panel(b).SetAlpha(0.5);
		TestDriver.pump(3);
		// red at a quarter over white: G and B at about 0xBF
		near(0xBF, (TestDriver.pixel(50, 30) >> 8) & 0xFF, "a quarter, not a half");
		// a restyle keeps the fade
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FF0000; opacity: 0.5;";
		TestDriver.pump(3);
		near(0xBF, (TestDriver.pixel(50, 30) >> 8) & 0xFF, "after a restyle");
		panel(b).SetAlpha(1);
		TestDriver.pump(3);
		near(0x7F, (TestDriver.pixel(50, 30) >> 8) & 0xFF, "the style's own half again");
	}

	static function near(expected:Int, channel:Int, msg:String) {
		Assert.isTrue(Math.abs(channel - expected) <= 3, '$msg: channel ${StringTools.hex(channel, 2)}');
	}

	static function panel(b:Box) {
		return (cast b : haxe.ui.backend.ComponentImpl).nativePanel;
	}

	static function red(left:Float, top:Float, w:Float, h:Float, style:String):Box {
		var b = new Box();
		b.left = left;
		b.top = top;
		b.width = w;
		b.height = h;
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FF0000; " + style;
		Screen.instance.addComponent(b);
		TestDriver.pump(3);
		return b;
	}
}
