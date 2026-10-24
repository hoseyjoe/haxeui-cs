package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.components.Button;
import haxe.ui.containers.Box;
import haxe.ui.containers.HorizontalSplitter;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import utest.Assert;

/** CSS cursor names as Avalonia cursors, a disabled component's cursor, and drag cursors. **/
class TestCursors extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testCssCursorNames() {
		var expected = [
			"pointer" => "Hand", "none" => "None", "not-allowed" => "No", "wait" => "Wait", "crosshair" => "Cross",
			"help" => "Help", "nwse-resize" => "TopLeftCorner", "nesw-resize" => "TopRightCorner",
			"ns-resize" => "SizeNorthSouth", "ew-resize" => "SizeWestEast", "grabbing" => "DragMove"
		];
		for (css => name in expected) {
			Assert.equals(name, UIStyle.StandardCursorName(css), css);
		}
	}

	function testDisabledComponentDropsCursor() {
		var b = new Button();
		b.text = "x";
		Screen.instance.addComponent(b);
		TestDriver.pump(2);
		Assert.equals("pointer", b.nativePanel.CursorName);
		b.disabled = true;
		TestDriver.pump(2);
		Assert.isNull(b.nativePanel.CursorName);
		b.disabled = false;
		TestDriver.pump(2);
		Assert.equals("pointer", b.nativePanel.CursorName);
	}

	function testSplitterDragHoldsScreenCursor() {
		var s = new HorizontalSplitter();
		s.width = 300;
		s.height = 100;
		var panes:Array<Component> = [];
		for (i in 0...2) {
			var bx = new Box();
			bx.percentWidth = 50;
			bx.percentHeight = 100;
			panes.push(bx);
			s.addComponent(bx);
		}
		Screen.instance.addComponent(s);
		TestDriver.pump(3);
		var grip = s.childComponents.filter(c -> panes.indexOf(c) == -1)[0];
		var p = TestDriver.centerOf(grip);
		TestDriver.mouseMove(p.x, p.y);
		TestDriver.mouseDown(p.x, p.y);
		TestDriver.pump();
		TestDriver.mouseMove(p.x + 20, p.y);
		TestDriver.pump();
		Assert.equals("col-resize", Host.ScreenCursorName);
		TestDriver.mouseUp(p.x + 20, p.y);
		TestDriver.pump();
		Assert.isNull(Host.ScreenCursorName);
	}
}
