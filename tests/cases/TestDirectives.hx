package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import utest.Assert;

/** html5's custom CSS directives, which haxeui-cs has too: rotation and clip-path. **/
class TestDirectives extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testRotation() {
		// a 100x20 bar at (100, 100) turned a quarter about its centre (150, 110)
		red(100, 100, 100, 20, "rotation: 90;");
		Assert.equals(0xFFFF0000, TestDriver.pixel(150, 140), "below the centre, now inside");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(190, 110), "the old right end, now empty");
	}

	function testClipPathInset() {
		red(0, 0, 100, 60, "clip-path: inset(10px 10px 10px 10px);");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(5, 5), "inside the inset margin");
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(95, 55), "the far corner too");
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
