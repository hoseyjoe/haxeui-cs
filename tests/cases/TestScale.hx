package cases;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.components.DropDown;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.MouseEvent;
import utest.Assert;

/** Toolkit.scale: the whole UI drawn larger, sizes and pointer positions in HaxeUI units. **/
class TestScale extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		Toolkit.scale = 1;
		var reset = new Box(); // the scale is taken up as a root component is added
		Screen.instance.addComponent(reset);
		Screen.instance.removeComponent(reset);
		TestDriver.pump();
	}

	function testScreenSizeDivides() {
		Toolkit.scale = 2;
		Assert.floatEquals(Host.ClientWidth / 2, Screen.instance.width);
		Assert.floatEquals(Host.ClientHeight / 2, Screen.instance.height);
	}

	function testRootDrawsScaled() {
		Toolkit.scale = 2;
		redBox(10, 10, 50, 30);
		Assert.equals(0xFFFF0000, TestDriver.pixel(25, 25), "inside, near the top left");
		Assert.equals(0xFFFF0000, TestDriver.pixel(115, 75), "inside, near the bottom right");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(125, 30), "past the scaled right edge");
	}

	function testClickInHaxeUIUnits() {
		Toolkit.scale = 2;
		var b = redBox(10, 10, 50, 30);
		var at:MouseEvent = null;
		b.registerEvent(MouseEvent.CLICK, e -> at = e);
		TestDriver.click(100, 50);
		Assert.notNull(at, "the click reached the box");
		if (at != null) {
			Assert.floatEquals(50, at.screenX);
			Assert.floatEquals(25, at.screenY);
		}
	}

	function testPopupIsScaled() {
		Toolkit.scale = 2;
		var dd = new DropDown();
		dd.left = 10;
		dd.top = 10;
		dd.width = 120;
		dd.dataSource = ArrayDataSource.fromArray([{text: "One"}, {text: "Two"}]);
		Screen.instance.addComponent(dd);
		TestDriver.pump(3);
		TestDriver.click((dd.screenLeft + 10) * 2, (dd.screenTop + 10) * 2);
		TestDriver.pump(3);
		var popup:Component = Screen.instance.rootComponents[Screen.instance.rootComponents.length - 1];
		Assert.isTrue(popup != dd, "the list opened");
		// its right border, where a scaled popup draws it
		var x = Std.int((popup.screenLeft + popup.width) * 2) - 1;
		var y = Std.int((popup.screenTop + popup.height / 2) * 2);
		Assert.isTrue(TestDriver.pixel(x, y) != 0xFFFFFFFF, 'popup border at ($x, $y)');
	}

	static function redBox(left:Float, top:Float, w:Float, h:Float):Box {
		var b = new Box();
		b.left = left;
		b.top = top;
		b.width = w;
		b.height = h;
		b.styleString = "border-size: 0px; padding: 0px; background-color: #FF0000;";
		Screen.instance.addComponent(b);
		TestDriver.pump(3);
		return b;
	}
}
