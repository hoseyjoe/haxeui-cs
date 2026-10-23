package cases;

import haxe.ui.components.Button;
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

	function testHasEventWithMethodClosure() {
		var component = new Component();
		var listener = new MoveListener();
		component.registerEvent(UIEvent.MOVE, listener.onMove);
		Assert.isTrue(component.hasEvent(UIEvent.MOVE, listener.onMove));
	}
}

private class MoveListener {
	public function new() {
	}

	public function onMove(e:UIEvent) {
	}
}
