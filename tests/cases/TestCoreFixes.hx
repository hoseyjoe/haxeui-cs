package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native.HeadlessDriver;
import haxe.ui.components.Button;
import haxe.ui.containers.Box;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.validation.ValidationManager;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import utest.Assert;

/** C#-only behaviour of haxeui-core itself, fixed in haxeui-core-joe. **/
class TestCoreFixes extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	// These two drive the real frame loop (callLater, then process()), never TestDriver.pump:
	// that calls ValidationManager.process() directly and would pass on the broken code.

	function testLayoutContinuesAfterAThrow() {
		var thrower = new Thrower();
		thrower.throwNext = true;
		Screen.instance.addComponent(thrower);
		HeadlessDriver.Pump(3); // the throw is reported on stderr by Host.RunFrame
		var later = new Box();
		later.width = 100;
		later.height = 20;
		Screen.instance.addComponent(later);
		HeadlessDriver.Pump(3);
		Assert.equals(100.0, later.nativePanel.W, "laid out and drawn after the throw");
		var before = thrower.layouts;
		thrower.invalidateComponentLayout();
		HeadlessDriver.Pump(3);
		Assert.isTrue(thrower.layouts > before, "the component that threw validates again");
	}

	function testSpinGuardDropsTheCycle() {
		var a = new Ping();
		var b = new Ping();
		a.other = b;
		b.other = a;
		Screen.instance.addComponent(a);
		Screen.instance.addComponent(b);
		HeadlessDriver.Pump(5);
		Assert.equals(0, @:privateAccess ValidationManager.instance._queue.length);
		var later = new Box();
		later.width = 50;
		later.height = 10;
		Screen.instance.addComponent(later);
		HeadlessDriver.Pump(3);
		Assert.equals(50.0, later.nativePanel.W, "layout goes on after the spin");
	}

	function testRegisterMouseOverDoesNotRecurse() {
		var button = new Button();
		button.registerEvent(MouseEvent.MOUSE_OVER, function(e) {});
		Assert.isTrue(button.hasEvent(MouseEvent.MOUSE_OVER));
	}

	function testItemRendererAcceptsNullData() {
		// DropDown renders its selected item before any data exists; Reflect.fields(null) throws on C#.
		var renderer = new haxe.ui.core.ItemRenderer();
		@:privateAccess renderer.updateValues(null);
		Assert.pass();
	}

	function testVariantFromAnonymousObject() {
		// DropDown's CHANGE event wraps the selected item ({text: ...}); C# refuses that cast.
		var v = haxe.ui.util.Variant.fromDynamic({text: "Two"});
		Assert.isTrue(v == null || v.isNull);
		Assert.equals("x", haxe.ui.util.Variant.fromDynamic("x").toString());
		Assert.equals(3, haxe.ui.util.Variant.fromDynamic(3).toInt());
	}

	function testHasEventWithMethodClosure() {
		var component = new Component();
		var listener = new MoveListener();
		component.registerEvent(UIEvent.MOVE, listener.onMove);
		Assert.isTrue(component.hasEvent(UIEvent.MOVE, listener.onMove));
	}

	function testDataSourceSortKeepsTiesInOrder() {
		// a table sorted by a column with equal values keeps those rows in their order, as html5 does
		var rows = [for (i in 0...16) {n: i % 2, id: String.fromCharCode(97 + i)}];
		var ds = ArrayDataSource.fromArray(rows);
		ds.sort("n");
		Assert.equals("acegikmobdfhjlnp", [for (i in 0...ds.size) ds.get(i).id].join(""));
	}
}

private class MoveListener {
	public function new() {
	}

	public function onMove(e:UIEvent) {
	}

}

/** Throws from its layout once, when asked to. **/
private class Thrower extends Box {
	public var throwNext = false;
	public var layouts = 0;

	private override function validateComponentLayout():Bool {
		layouts++;
		if (throwNext) {
			throwNext = false;
			throw "deliberate failure in a layout";
		}
		return super.validateComponentLayout();
	}
}

/** Invalidates its partner whenever it lays out: two of them spin forever. **/
private class Ping extends Box {
	public var other:Component;

	private override function validateComponentLayout():Bool {
		if (other != null) {
			other.invalidateComponentLayout();
		}
		return super.validateComponentLayout();
	}
}
