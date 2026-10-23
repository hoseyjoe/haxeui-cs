package cases;

import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.components.Canvas;
import haxe.ui.components.DropDown;
import haxe.ui.components.Image;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextArea;
import haxe.ui.components.TextField;
import haxe.ui.containers.Absolute;
import haxe.ui.containers.Box;
import haxe.ui.containers.HBox;
import haxe.ui.containers.HorizontalSplitter;
import haxe.ui.containers.ListView;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.TreeViewNode;
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.core.Component;
import haxe.ui.core.ItemRenderer;
import haxe.ui.core.Screen;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.tooltips.ToolTipManager;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Every component Joeditor builds, under the dark theme, behaving as Joeditor needs. **/
class TestGallery extends utest.Test {
	function setupClass() {
		Toolkit.theme = "dark";
	}

	function teardownClass() {
		Toolkit.theme = "default";
	}

	function teardown() {
		TestDriver.mouseMove(795, 595);
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump(2);
	}

	function testDropdownPopup() {
		var dropdown = new DropDown();
		dropdown.left = 20;
		dropdown.top = 20;
		dropdown.width = 150;
		dropdown.dataSource = ArrayDataSource.fromArray([{text: "One"}, {text: "Two"}, {text: "Three"}]);
		Screen.instance.addComponent(dropdown);
		TestDriver.pump(2);
		var roots = Screen.instance.rootComponents.length;

		TestDriver.clickComponent(dropdown);
		TestDriver.pump(2);
		Assert.equals(roots + 1, Screen.instance.rootComponents.length, "list opened as a root");
		var popup = Screen.instance.rootComponents[Screen.instance.rootComponents.length - 1];
		var items = popup.findComponents(ItemRenderer);
		Assert.isTrue(items.length >= 3, 'items ${items.length}');

		TestDriver.clickComponent(items[1]);
		TestDriver.pump(2);
		Assert.equals(1, dropdown.selectedIndex);
		Assert.equals(roots, Screen.instance.rootComponents.length, "list closed after choosing");

		TestDriver.clickComponent(dropdown);
		TestDriver.pump(2);
		Assert.equals(roots + 1, Screen.instance.rootComponents.length, "list reopened");
		TestDriver.click(700, 500);
		TestDriver.pump(2);
		Assert.equals(roots, Screen.instance.rootComponents.length, "outside click closes it");
	}

	function testTreeViewExpandSelect() {
		var tree = new TreeView();
		tree.left = 20;
		tree.top = 20;
		tree.width = 220;
		tree.height = 200;
		var first = tree.addNode({text: "Node 0"});
		var children = [for (i in 0...20) first.addNode({text: 'Child $i'})];
		for (i in 1...180) {
			tree.addNode({text: 'Node $i'});
		}
		Screen.instance.addComponent(tree);
		TestDriver.pump(3);

		first.expanded = true;
		TestDriver.pump(3);
		var child = children[2];
		var c = TestDriver.centerOf(child);
		TestDriver.click(c.x, c.y);
		TestDriver.pump(2);
		Assert.isTrue(tree.selectedNode == child, 'selected ${tree.selectedNode == null ? null : tree.selectedNode.text}');

		var middle = TestDriver.centerOf(tree);
		TestDriver.mouseMove(middle.x, middle.y);
		TestDriver.wheel(middle.x, middle.y, -1);
		TestDriver.pump(2);
		Assert.isTrue(tree.vscrollPos > 0, 'vscrollPos ${tree.vscrollPos}');
	}

	function testSplitterDrag() {
		var splitter = new HorizontalSplitter();
		splitter.left = 20;
		splitter.top = 20;
		splitter.width = 400;
		splitter.height = 120;
		var left = new Box();
		left.width = 150;
		left.percentHeight = 100;
		var right = new Box();
		right.percentWidth = 100;
		right.percentHeight = 100;
		splitter.addComponent(left);
		splitter.addComponent(right);
		Screen.instance.addComponent(splitter);
		TestDriver.pump(3);

		var grippers = splitter.findComponents("horizontal-splitter-gripper", Component, 1);
		Assert.equals(1, grippers.length);
		var before = left.width;
		var g = TestDriver.centerOf(grippers[0]);
		TestDriver.mouseMove(g.x, g.y);
		TestDriver.mouseDown(g.x, g.y);
		TestDriver.pump();
		TestDriver.mouseMove(g.x + 20, g.y);
		TestDriver.pump();
		TestDriver.mouseMove(g.x + 40, g.y);
		TestDriver.pump();
		TestDriver.mouseUp(g.x + 40, g.y);
		TestDriver.pump(3);
		Assert.isTrue(Math.abs(left.width - (before + 40)) <= 2, 'left pane ${before} -> ${left.width}');
	}

	function testTooltipAppears() {
		var button = new Button();
		button.text = "Hover me";
		button.tooltip = "A tooltip";
		button.left = 40;
		button.top = 40;
		Screen.instance.addComponent(button);
		TestDriver.pump(2);

		var c = TestDriver.centerOf(button);
		TestDriver.mouseMove(c.x, c.y);
		TestDriver.mouseMove(c.x + 1, c.y);
		pumpFor(ToolTipManager.defaultDelay + 600);
		var tip:Component = @:privateAccess ToolTipManager.instance._toolTip;
		Assert.notNull(tip, "a tooltip was created");
		Assert.isTrue(tip != null && tip.hidden == false && Screen.instance.rootComponents.indexOf(tip) != -1, "it is on screen");

		TestDriver.mouseMove(700, 500);
		pumpFor(300);
		Assert.isTrue(tip == null || tip.hidden || Screen.instance.rootComponents.indexOf(tip) == -1, "it goes away");
	}

	function testMessageBoxShowsAndCloses() {
		var answered:DialogButton = null;
		var roots = Screen.instance.rootComponents.length;
		Dialogs.messageBox("Saved.", "Joeditor", null, true, button -> answered = button);
		TestDriver.pump(3);
		Assert.isTrue(Screen.instance.rootComponents.length > roots, "the box is on screen");
		var box = Screen.instance.rootComponents[Screen.instance.rootComponents.length - 1];
		var ok = box.findComponents(Button).filter(b -> b.text == "OK");
		Assert.equals(1, ok.length);
		TestDriver.clickComponent(ok[0]);
		TestDriver.pump(3);
		Assert.isTrue(answered == DialogButton.OK);
		Assert.equals(roots, Screen.instance.rootComponents.length, "the box is gone");
	}

	function testGalleryCapture() {
		var root = new HBox();
		root.left = 10;
		root.top = 10;
		var column = new VBox();
		var label = new Label();
		label.text = "Joeditor gallery — “dark”";
		column.addComponent(label);
		var button = new Button();
		button.text = "Button";
		column.addComponent(button);
		var dropdown = new DropDown();
		dropdown.width = 160;
		dropdown.dataSource = ArrayDataSource.fromArray([{text: "Choice"}]);
		dropdown.selectedIndex = 0;
		column.addComponent(dropdown);
		var field = new TextField();
		field.width = 160;
		field.text = "Text field";
		column.addComponent(field);
		var area = new TextArea();
		area.width = 160;
		area.height = 60;
		area.text = "A text area\nsecond line";
		column.addComponent(area);
		var stepper = new NumberStepper();
		stepper.pos = 7;
		column.addComponent(stepper);
		var image = new Image();
		image.resource = "slice9.png";
		image.width = 24;
		image.height = 24;
		column.addComponent(image);
		root.addComponent(column);

		var tree = new TreeView();
		tree.width = 200;
		tree.height = 200;
		var node = tree.addNode({text: "City"});
		node.addNode({text: "Garrison"});
		node.addNode({text: "Intro beat"});
		node.expanded = true;
		tree.addNode({text: "Road event"});
		root.addComponent(tree);

		var canvas = new Canvas();
		canvas.width = 200;
		canvas.height = 200;
		var g = canvas.componentGraphics;
		g.fillStyle(0x2B6A9E);
		g.rectangle(0, 0, 200, 200);
		g.fillStyle(0x6E9B4C);
		g.moveTo(30, 40);
		g.lineTo(150, 30);
		g.lineTo(170, 150);
		g.lineTo(60, 170);
		g.fillStyle(null);
		g.strokeStyle(0xE8D9A0, 2);
		g.circle(100, 100, 8);
		root.addComponent(canvas);

		Screen.instance.addComponent(root);
		TestDriver.pump(4);
		TestDriver.capture("tests/bin/gallery.png");
		Assert.isTrue(sys.FileSystem.exists("tests/bin/gallery.png"));
	}

	static function pumpFor(milliseconds:Int) {
		var end = haxe.Timer.stamp() + milliseconds / 1000;
		while (haxe.Timer.stamp() < end) {
			TestDriver.pump();
			Sys.sleep(0.01);
		}
	}
}
