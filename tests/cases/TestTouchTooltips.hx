package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.touch.TouchTooltips;
import haxe.ui.components.Button;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.tooltips.ToolTipManager;
import utest.Assert;

/** A long press shows a component's tooltip, for touch screens (installed on Android). **/
class TestTouchTooltips extends utest.Test {
	var button:Button;
	var clicks:Int;

	function setup() {
		// HaxeUI keeps one tooltip for everything, and its fades chain their end handlers onto the
		// tooltip: one left over from another test can hide the one this test shows, or the other
		// way round. Each test here starts and ends with a fresh one.
		ToolTipManager.instance.reset();
		TouchTooltips.install();
		button = new Button();
		button.text = "X";
		button.left = 20;
		button.top = 20;
		Screen.instance.addComponent(button);
		// Set after it is on screen, through registerTooltip as a `tooltip` attribute would be, but
		// with no hover: a finger has none, and the desktop's hover tooltip would answer for this.
		@:privateAccess ToolTipManager.instance._toolTipOptions.set(button, {tipData: {text: "Tip"}});
		clicks = 0;
		button.onClick = _ -> clicks++;
		TestDriver.pump(2);
	}

	function teardown() {
		ToolTipManager.instance.unregisterTooltip(button);
		Screen.instance.removeComponent(button);
		ToolTipManager.instance.reset();
		TestDriver.pump();
	}

	function testHoldShowsTooltip() {
		var c = TestDriver.centerOf(button);
		TestDriver.mouseDown(c.x, c.y);
		hold(0.7);
		Assert.equals("Tip", tipText());
		TestDriver.mouseUp(c.x, c.y);
		TestDriver.pump();
	}

	function testReleaseAfterHoldHidesAndDoesNotClick() {
		var c = TestDriver.centerOf(button);
		TestDriver.mouseDown(c.x, c.y);
		hold(0.7);
		TestDriver.mouseUp(c.x, c.y);
		hold(0.5); // the tooltip fades out
		Assert.isNull(tipText());
		Assert.equals(0, clicks);
	}

	function testShortTapClicksWithoutTooltip() {
		var c = TestDriver.centerOf(button);
		TestDriver.mouseDown(c.x, c.y);
		TestDriver.pump(2);
		TestDriver.mouseUp(c.x, c.y);
		hold(0.7);
		Assert.equals(1, clicks);
		Assert.isNull(tipText());
	}

	function testMoveBeyondSlopCancels() {
		var c = TestDriver.centerOf(button);
		TestDriver.mouseDown(c.x, c.y);
		TestDriver.mouseMove(c.x + 20, c.y);
		hold(0.7);
		Assert.isNull(tipText());
		TestDriver.mouseUp(c.x + 20, c.y);
		TestDriver.pump();
	}

	/** Pumps for `seconds` of wall-clock time: a long press is measured in real time. **/
	static function hold(seconds:Float) {
		var end = haxe.Timer.stamp() + seconds;
		while (haxe.Timer.stamp() < end) {
			TestDriver.pump();
			Sys.sleep(0.01);
		}
		TestDriver.pump(2);
	}

	/** The tooltip's text while one is up, else null. **/
	static function tipText():Null<String> {
		var tip = @:privateAccess ToolTipManager.instance._toolTip;
		if (tip == null || tip.hidden || tip.parentComponent == null && Screen.instance.rootComponents.indexOf(tip) < 0) return null;
		var label = tip.findComponent(haxe.ui.components.Label, true);
		return label != null ? label.text : null;
	}
}
