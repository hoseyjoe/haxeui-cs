package cases;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.TextLinkEvent;
import haxe.ui.components.Label;
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
		// A root component's left and top are screen pixels, as core places its drop-down lists,
		// dialogs and tooltips; its size is HaxeUI units, drawn at the scale.
		Toolkit.scale = 2;
		redBox(10, 10, 50, 30);
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(5, 5), "before its left and top");
		Assert.equals(0xFFFF0000, TestDriver.pixel(15, 15), "inside, near the top left");
		Assert.equals(0xFFFF0000, TestDriver.pixel(105, 65), "inside, near the bottom right");
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(115, 30), "past the scaled right edge");
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
		var dd = dropDown();
		var popup = open(dd);
		Assert.isTrue(popup != dd, "the list opened");
		// its right border, where a scaled popup draws it
		var x = Std.int(popup.screenLeft + popup.actualComponentWidth) - 1;
		var y = Std.int(popup.screenTop + popup.actualComponentHeight / 2);
		Assert.isTrue(TestDriver.pixel(x, y) != 0xFFFFFFFF, 'popup border at ($x, $y)');
	}

	function testScaledPopupsLastItemCanBeChosen() {
		// The drop-down takes a press outside its list as a dismissal, measured where core put the
		// list: a list drawn anywhere else lost its lower items to that, closing unchosen.
		Toolkit.scale = 2;
		var dd = dropDown();
		var popup = open(dd);
		TestDriver.click(popup.screenLeft + popup.actualComponentWidth / 2, popup.screenTop + popup.actualComponentHeight * 0.75);
		TestDriver.pump(3);
		Assert.equals(1, dd.selectedIndex);
	}

	function testScaledLinkIsFoundWhereItIsDrawn() {
		// screenLeft is screen pixels and a pointer's position HaxeUI units: away from the origin
		// they part, and a tap on a link drawn there missed it.
		Toolkit.scale = 2;
		var box = new haxe.ui.containers.Absolute();
		box.left = 10;
		box.top = 10;
		box.width = 300;
		box.height = 200;
		var l = new Label();
		l.left = 40;
		l.top = 60;
		l.htmlText = 'Go <a href="target">there</a> now';
		box.addComponent(l);
		Screen.instance.addComponent(box);
		TestDriver.pump(3);
		var got:Array<String> = [];
		l.registerEvent(TextLinkEvent.LINK, e -> got.push(e.href + "#" + e.index));
		var r = l.getTextDisplay().linkRects()[0];
		TestDriver.click(l.screenLeft + (r.left + r.width / 2) * 2, l.screenTop + (r.top + r.height / 2) * 2);
		Assert.same(["target#0"], got);
	}

	static function dropDown():DropDown {
		var dd = new DropDown();
		dd.left = 10;
		dd.top = 10;
		dd.width = 120;
		dd.dataSource = ArrayDataSource.fromArray([{text: "One"}, {text: "Two"}]);
		Screen.instance.addComponent(dd);
		TestDriver.pump(3);
		return dd;
	}

	/** Opens `dd`'s list with a click and returns it (the newest root component). **/
	static function open(dd:DropDown):Component {
		TestDriver.click(dd.screenLeft + 20, dd.screenTop + 20);
		TestDriver.pump(3);
		return Screen.instance.rootComponents[Screen.instance.rootComponents.length - 1];
	}

	function testSvgSharpWhenScaled() {
		// red left half, blue right half: drawn for the scaled size, the edge stays a clean step
		Toolkit.scale = 2;
		var image = new haxe.ui.components.Image();
		image.resource = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="5" height="10" fill="#ff0000"/><rect x="5" width="5" height="10" fill="#0000ff"/></svg>';
		image.width = 20;
		image.height = 20;
		Screen.instance.addComponent(image);
		TestDriver.pump(3);
		var left = TestDriver.pixel(19, 20), right = TestDriver.pixel(20, 20);
		Assert.isTrue(close(left, 0xFFFF0000) && close(right, 0xFF0000FF), 'edge ${StringTools.hex(left, 8)} | ${StringTools.hex(right, 8)}');
	}

	static function close(a:Int, b:Int):Bool {
		for (shift in [16, 8, 0]) {
			if (Math.abs(((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)) > 8) {
				return false;
			}
		}
		return true;
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
