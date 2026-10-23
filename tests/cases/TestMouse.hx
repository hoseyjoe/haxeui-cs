package cases;

import haxe.ui.components.Button;
import haxe.ui.containers.Box;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Pointer input reaching HaxeUI components through Avalonia's routed events. **/
class TestMouse extends utest.Test {
	function teardown() {
		TestDriver.mouseMove(790, 590);
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testButtonClickFiresOnce() {
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		TestDriver.clickComponent(button);
		Assert.equals(1, clicks);
	}

	function testQuickClicksEachFire() {
		// a browser fires click for every click, a second one inside the double-click time included
		var button = addButton();
		var clicks = 0;
		var doubles = 0;
		button.onClick = e -> clicks++;
		button.registerEvent(MouseEvent.DBL_CLICK, e -> doubles++);
		TestDriver.clickComponent(button);
		TestDriver.clickComponent(button);
		Assert.equals(2, clicks);
		Assert.equals(1, doubles);
	}

	function testClickOnlyWhenReleasedInside() {
		// pressed on the button, released elsewhere: no click (as in a browser)
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		var c = TestDriver.centerOf(button);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.mouseDown(c.x, c.y);
		TestDriver.mouseMove(600, 400);
		TestDriver.mouseUp(600, 400);
		TestDriver.pump();
		Assert.equals(0, clicks);
	}

	function testHoverAddsHoverClass() {
		var button = addButton();
		var c = TestDriver.centerOf(button);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.pump();
		Assert.isTrue(button.hasClass(":hover"));
		TestDriver.mouseMove(700, 500);
		TestDriver.pump();
		Assert.isFalse(button.hasClass(":hover"));
	}

	function testRightClick() {
		var button = addButton();
		var rightClicks = 0;
		button.registerEvent(MouseEvent.RIGHT_CLICK, e -> rightClicks++);
		var c = TestDriver.centerOf(button);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.mouseDown(c.x, c.y, 2);
		TestDriver.mouseUp(c.x, c.y, 2);
		TestDriver.pump();
		Assert.equals(1, rightClicks);
	}

	function testWheelScrollsInnermost() {
		var outer = new ScrollView();
		outer.width = 200;
		outer.height = 200;
		var column = new VBox();
		var inner = new ScrollView();
		inner.width = 150;
		inner.height = 100;
		inner.addComponent(box(120, 400));
		column.addComponent(inner);
		column.addComponent(box(120, 600));
		outer.addComponent(column);
		Screen.instance.addComponent(outer);
		TestDriver.pump(3);

		var c = TestDriver.centerOf(inner);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.wheel(c.x, c.y, -1);
		TestDriver.pump(2);
		Assert.isTrue(inner.vscrollPos > 0, 'inner ${inner.vscrollPos}');
		Assert.equals(0.0, outer.vscrollPos);
	}

	function testScrollbarThumbDrag() {
		var scroll = new ScrollView();
		scroll.width = 100;
		scroll.height = 100;
		scroll.addComponent(box(80, 400));
		Screen.instance.addComponent(scroll);
		TestDriver.pump(3);

		var thumb = scroll.findComponent("scroll-thumb-button", Component);
		Assert.notNull(thumb);
		var c = TestDriver.centerOf(thumb);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.mouseDown(c.x, c.y);
		TestDriver.pump();
		TestDriver.mouseMove(c.x, c.y + 25);
		TestDriver.pump();
		TestDriver.mouseMove(c.x, c.y + 50);
		TestDriver.pump();
		TestDriver.mouseUp(c.x, c.y + 50);
		TestDriver.pump(2);
		Assert.isTrue(scroll.vscrollPos > 0, 'vscrollPos ${scroll.vscrollPos}');
	}

	function testPointerEventsNoneClicksThrough() {
		// HaxeUI's click-through overlays (ColorPicker's indicator) are styled pointer-events: none.
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		var cover = new Box();
		cover.width = 300;
		cover.height = 200;
		cover.styleString = "pointer-events: none; background-color: #FF0000; background-opacity: 0.1;";
		Screen.instance.addComponent(cover);
		TestDriver.pump(2);
		TestDriver.clickComponent(button);
		Assert.equals(1, clicks);
	}

	function testDisabledButtonNoClick() {
		var button = addButton();
		var clicks = 0;
		button.onClick = e -> clicks++;
		button.disabled = true;
		TestDriver.pump();
		TestDriver.clickComponent(button);
		Assert.equals(0, clicks);
	}

	static function addButton():Button {
		var button = new Button();
		button.text = "Press";
		button.left = 20;
		button.top = 20;
		Screen.instance.addComponent(button);
		TestDriver.pump(2);
		return button;
	}

	static function box(w:Float, h:Float):Box {
		var b = new Box();
		b.width = w;
		b.height = h;
		return b;
	}
}
