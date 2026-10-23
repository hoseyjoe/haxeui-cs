package cases;

import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextArea;
import haxe.ui.components.TextField;
import haxe.ui.core.Screen;
import haxe.ui.focus.FocusManager;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Native text input, typing, keys and focus. **/
class TestTextInput extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testTypeIntoTextField() {
		var field = addTextField(20, 20);
		var changes = 0;
		field.onChange = e -> changes++;
		TestDriver.clickComponent(field);
		TestDriver.type("abc");
		TestDriver.pump(2);
		Assert.equals("abc", field.text);
		Assert.isTrue(changes >= 1, 'changes $changes');
	}

	function testTextAreaEnterNewline() {
		var area = new TextArea();
		area.left = 20;
		area.top = 20;
		area.width = 200;
		area.height = 100;
		Screen.instance.addComponent(area);
		TestDriver.pump(2);
		TestDriver.clickComponent(area);
		TestDriver.type("a");
		TestDriver.key("Enter");
		TestDriver.type("b");
		TestDriver.pump(2);
		Assert.equals("a\nb", area.text);
	}

	function testPasswordMasks() {
		var field = addTextField(20, 20);
		field.password = true;
		TestDriver.pump(2);
		Assert.isTrue(field.getTextInput().inputNative.IsPassword);
	}

	function testTabMovesFocus() {
		// HaxeUI tabs within one view (one root component), as an app's fields would be.
		var form = new haxe.ui.containers.VBox();
		form.left = 20;
		form.top = 20;
		var first = new TextField();
		var second = new TextField();
		first.width = second.width = 200;
		form.addComponent(first);
		form.addComponent(second);
		Screen.instance.addComponent(form);
		TestDriver.pump(2);
		TestDriver.clickComponent(first);
		TestDriver.pump();
		Assert.isTrue(FocusManager.instance.focus == first);
		TestDriver.key("Tab");
		TestDriver.pump(2);
		Assert.isTrue(FocusManager.instance.focus == second);
	}

	function testNumberStepperTyping() {
		var stepper = new NumberStepper();
		stepper.left = 20;
		stepper.top = 20;
		stepper.max = 100;
		Screen.instance.addComponent(stepper);
		TestDriver.pump(2);
		var field = stepper.findComponent(TextField);
		Assert.notNull(field);
		TestDriver.clickComponent(field);
		TestDriver.key("A", true);
		TestDriver.type("42");
		TestDriver.key("Enter");
		TestDriver.pump(2);
		Assert.equals(42.0, stepper.pos);
	}

	function testUnicodeRoundTrip() {
		var text = "Café — “quoted”";
		var field = addTextField(20, 20);
		field.text = text;
		TestDriver.pump(2);
		Assert.equals(text, field.getTextInput().inputNative.Text);
		Assert.equals(text, field.text);

		var typed = addTextField(20, 70);
		TestDriver.clickComponent(typed);
		TestDriver.type(text);
		TestDriver.pump(2);
		Assert.equals(text, typed.text);
	}

	function testProgrammaticTextNoUserEcho() {
		var field = addTextField(20, 20);
		var changes = 0;
		field.onChange = e -> changes++;
		field.text = "set in code";
		TestDriver.pump(2);
		Assert.equals("set in code", field.getTextInput().inputNative.Text);
		Assert.isTrue(changes <= 1, 'changes $changes');
	}

	static function addTextField(left:Float, top:Float):TextField {
		var field = new TextField();
		field.left = left;
		field.top = top;
		field.width = 200;
		Screen.instance.addComponent(field);
		TestDriver.pump(2);
		return field;
	}
}
