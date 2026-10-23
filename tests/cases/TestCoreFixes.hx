package cases;

import haxe.ui.components.Button;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.core.Component;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import utest.Assert;

/** C#-only behaviour of haxeui-core itself, fixed in haxeui-core-joe. **/
class TestCoreFixes extends utest.Test {
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
