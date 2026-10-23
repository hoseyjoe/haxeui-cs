package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.IPanelListener;
import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;

/**
 * Turns native input (IPanelListener calls) into HaxeUI events for whatever
 * listeners a component or the screen has mapped.
 */
class InputListener implements IPanelListener {
	public var mapping(default, null):Map<String, UIEvent->Void> = new Map<String, UIEvent->Void>();

	public function new() {
	}

	public function OnPointer(kind:Int, screenX:Float, screenY:Float, buttonDown:Bool, ctrl:Bool, shift:Bool, alt:Bool, wheelDelta:Float, nativeEvent:Dynamic):Void {
		var type = EventMapper.typeOf(kind);
		var fn = mapping.get(type);
		if (fn == null) {
			return;
		}
		var event = new MouseEvent(type);
		@:privateAccess event._originalEvent = nativeEvent;
		event.screenX = screenX;
		event.screenY = screenY;
		event.buttonDown = buttonDown;
		event.ctrlKey = ctrl;
		event.shiftKey = shift;
		event.delta = wheelDelta;
		fn(event);
	}

	public function OnKey(kind:Int, keyCode:Int, ctrl:Bool, shift:Bool, alt:Bool, nativeEvent:Dynamic):Void {
		var type = EventMapper.typeOf(kind);
		var fn = mapping.get(type);
		if (fn == null) {
			return;
		}
		var event = new KeyboardEvent(type);
		@:privateAccess event._originalEvent = nativeEvent;
		event.keyCode = keyCode;
		event.ctrlKey = ctrl;
		event.shiftKey = shift;
		event.altKey = alt;
		fn(event);
	}

	public var mask(get, never):Int;
	private function get_mask():Int {
		return EventMapper.maskOf(mapping.keys());
	}
}
