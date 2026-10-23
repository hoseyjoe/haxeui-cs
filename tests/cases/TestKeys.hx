package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.core.Screen;
import haxe.ui.events.KeyboardEvent;
import utest.Assert;

/** Keys arrive as the browser's key codes, which is what HaxeUI and its apps compare against. **/
class TestKeys extends utest.Test {
	static var EXPECTED:Array<{key:String, code:Int}> = [
		{key: "A", code: 65}, {key: "Enter", code: 13},
		{key: "CapsLock", code: 20}, {key: "Pause", code: 19}, {key: "PrintScreen", code: 44},
		{key: "LWin", code: 91}, {key: "RWin", code: 92}, {key: "Apps", code: 93},
		{key: "Multiply", code: 106}, {key: "Add", code: 107}, {key: "Subtract", code: 109},
		{key: "Decimal", code: 110}, {key: "Divide", code: 111},
		{key: "F13", code: 124}, {key: "F24", code: 135},
		{key: "NumLock", code: 144}, {key: "Scroll", code: 145},
		{key: "OemSemicolon", code: 186}, {key: "OemPlus", code: 187}, {key: "OemComma", code: 188},
		{key: "OemMinus", code: 189}, {key: "OemPeriod", code: 190}, {key: "OemQuestion", code: 191},
		{key: "OemTilde", code: 192}, {key: "OemOpenBrackets", code: 219}, {key: "OemPipe", code: 220},
		{key: "OemCloseBrackets", code: 221}, {key: "OemQuotes", code: 222}, {key: "OemBackslash", code: 226},
	];

	function testBrowserKeyCodes() {
		var codes:Array<Int> = [];
		var listener = (e:KeyboardEvent) -> codes.push(e.keyCode);
		Screen.instance.registerEvent(KeyboardEvent.KEY_DOWN, listener);
		for (k in EXPECTED) {
			codes = [];
			TestDriver.key(k.key);
			TestDriver.pump();
			Assert.equals(k.code, codes[0], k.key);
		}
		Screen.instance.unregisterEvent(KeyboardEvent.KEY_DOWN, listener);
	}
}
