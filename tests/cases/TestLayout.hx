package cases;

import haxe.ui.components.Spacer;
import haxe.ui.containers.Box;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Component tree and geometry mirrored onto native panels. **/
class TestLayout extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.resizeWindow(800, 600);
		TestDriver.pump();
	}

	function testFixedBoxesInVBox() {
		var vbox = new VBox();
		vbox.styleString = "spacing: 5px; padding: 0px;";
		vbox.left = 10;
		vbox.top = 20;
		var a = box(100, 30);
		var b = box(50, 40);
		vbox.addComponent(a);
		vbox.addComponent(b);
		Screen.instance.addComponent(vbox);
		TestDriver.pump();

		Assert.equals(10.0, vbox.nativePanel.Left);
		Assert.equals(20.0, vbox.nativePanel.Top);
		assertBounds(a, 0, 0, 100, 30);
		assertBounds(b, 0, 35, 50, 40);
	}

	function testHiddenComponentHidesPanel() {
		var c = box(10, 10);
		Screen.instance.addComponent(c);
		TestDriver.pump();
		Assert.isTrue(c.nativePanel.IsVisible);
		c.hide();
		TestDriver.pump();
		Assert.isFalse(c.nativePanel.IsVisible);
	}

	function testRemoveComponentRemovesPanel() {
		var parent = new VBox();
		var a = box(10, 10);
		var b = box(10, 10);
		parent.addComponent(a);
		parent.addComponent(b);
		Screen.instance.addComponent(parent);
		TestDriver.pump();
		var before = parent.nativePanel.ChildCount;
		parent.removeComponent(a);
		TestDriver.pump();
		Assert.equals(before - 1, parent.nativePanel.ChildCount);
		Assert.equals(-1, parent.nativePanel.IndexOfChild(a.nativePanel));
	}

	function testSetComponentIndexReorders() {
		var parent = new Box();
		var a = box(10, 10);
		var b = box(10, 10);
		var c = box(10, 10);
		parent.addComponent(a);
		parent.addComponent(b);
		parent.addComponent(c);
		Screen.instance.addComponent(parent);
		parent.setComponentIndex(c, 0);
		TestDriver.pump();
		var last = -1;
		for (child in parent.childComponents) {
			var i = parent.nativePanel.IndexOfChild(child.nativePanel);
			Assert.isTrue(i > last, 'native order of ${child.id} follows childComponents');
			last = i;
		}
		Assert.isTrue(parent.childComponents[0] == c);
	}

	function testReparentWithoutRemove() {
		// html5 and heaps move a node that is added elsewhere; HaxeUI apps rely on it.
		var from = new VBox();
		var to = new VBox();
		var moved = box(20, 20);
		from.addComponent(moved);
		var root = new VBox();
		root.addComponent(from);
		root.addComponent(to);
		Screen.instance.addComponent(root);
		TestDriver.pump();
		to.addComponent(moved);
		TestDriver.pump();
		Assert.equals(-1, from.nativePanel.IndexOfChild(moved.nativePanel));
		Assert.equals(0, to.nativePanel.IndexOfChild(moved.nativePanel));
	}

	function testRootReparentWithoutRemove() {
		// a root component later added into a container
		var moved = box(20, 20);
		Screen.instance.addComponent(moved);
		var holder = new VBox();
		Screen.instance.addComponent(holder);
		TestDriver.pump();
		holder.addComponent(moved);
		TestDriver.pump();
		Assert.equals(0, holder.nativePanel.IndexOfChild(moved.nativePanel));
	}

	function testClipRect() {
		var scroll = new ScrollView();
		scroll.width = 100;
		scroll.height = 100;
		scroll.addComponent(box(300, 300));
		Screen.instance.addComponent(scroll);
		TestDriver.pump(3);
		var contents = scroll.findComponent("scrollview-contents", Component);
		Assert.notNull(contents);
		Assert.isTrue(contents.nativePanel.ClipEnabled);
		Assert.isTrue(contents.nativePanel.ClipWidth > 0 && contents.nativePanel.ClipWidth <= 100);
		Assert.isTrue(contents.nativePanel.ClipHeight > 0 && contents.nativePanel.ClipHeight <= 100);
	}

	function testWindowResizeRelayout() {
		var root = new VBox();
		root.percentWidth = 100;
		root.addComponent(new Spacer());
		Screen.instance.addComponent(root);
		TestDriver.pump();
		Assert.equals(800.0, root.width);
		TestDriver.resizeWindow(500, 400);
		TestDriver.pump(2);
		Assert.equals(500.0, Screen.instance.width);
		Assert.equals(500.0, root.width);
	}

	static function box(w:Float, h:Float):Box {
		var b = new Box();
		b.width = w;
		b.height = h;
		return b;
	}

	static function assertBounds(c:Component, l:Float, t:Float, w:Float, h:Float, ?pos:haxe.PosInfos) {
		var p = c.nativePanel;
		Assert.equals(l, p.Left, pos);
		Assert.equals(t, p.Top, pos);
		Assert.equals(w, p.W, pos);
		Assert.equals(h, p.H, pos);
	}
}
