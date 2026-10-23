package cases;

import haxe.ui.ComponentBuilder;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextArea;
import haxe.ui.components.TextField;
import haxe.ui.containers.ListView;
import haxe.ui.containers.VBox;
import haxe.ui.core.InteractiveComponent;
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

	function testTextAreaAppendThenTabOut() {
		// Joeditor's prose box: starts with words, gets more typed at the end, commits on focus out.
		// The same shape as Joeditor's: wrapping, auto height up to a cap, and more words than fit.
		var initial = "Providence. The box of my grand-uncle's papers sits open on the desk: a clay bas-relief "
			+ "still damp from a sculptor's dreams, and a file the old professor kept under lock - CTHULHU CULT, "
			+ "in a hand that shook. The most merciful thing in the world is the inability of the mind to "
			+ "correlate all its contents. I have correlated mine, and an expedition waits at the docks.";
		var form = new haxe.ui.containers.VBox();
		form.left = 20;
		form.top = 20;
		form.width = 320;
		var area = new TextArea();
		area.percentWidth = 100;
		area.wrap = true;
		area.styleString = "height: auto; max-height: 100px;";
		area.text = initial;
		var other = new TextField();
		other.width = 200;
		form.addComponent(area);
		form.addComponent(other);
		Screen.instance.addComponent(form);
		TestDriver.pump(3);
		var atFocusOut:String = "(never)";
		area.registerEvent(haxe.ui.events.FocusEvent.FOCUS_OUT, e -> atFocusOut = area.text);

		TestDriver.clickComponent(area);
		Assert.equals(initial, area.text, "clicking keeps the words");
		TestDriver.key("End", true);
		TestDriver.type(" More.");
		TestDriver.pump(2);
		Assert.equals(initial + " More.", area.text, "typing reaches the box");
		TestDriver.key("Tab");
		TestDriver.pump(2);
		Assert.equals(initial + " More.", atFocusOut, "focus out sees the words");
	}

	function testRemovingFocusedFieldDropsFocus() {
		// Joeditor swaps its property panel while a field there still has focus; a later
		// focus change must not send that removed, disposed field a FOCUS_OUT.
		var form = new haxe.ui.containers.VBox();
		form.left = 20;
		form.top = 20;
		var panel = new haxe.ui.containers.VBox();
		var field = new TextField();
		field.width = 200;
		field.text = "kept";
		panel.addComponent(field);
		var other = new TextField();
		other.width = 200;
		form.addComponent(panel);
		form.addComponent(other);
		Screen.instance.addComponent(form);
		TestDriver.pump(2);
		TestDriver.clickComponent(field);
		Assert.isTrue(field.focus);

		// As a browser drops a removed element's focus: quietly. An event here would re-enter
		// the app in the middle of whatever is tearing its panel down (Joeditor: a commit).
		var seen:Array<String> = [];
		field.registerEvent(haxe.ui.events.FocusEvent.FOCUS_OUT, e -> seen.push(field.text));
		panel.removeComponent(field);
		TestDriver.pump();
		Assert.equals(0, seen.length, "no focus out as it is removed");
		Assert.isFalse(field.focus, "but it no longer has the focus");

		TestDriver.clickComponent(other);
		TestDriver.pump();
		Assert.equals(0, seen.length, "nor once it is gone");
		Assert.isTrue(FocusManager.instance.focus == other);
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

	function testTextAreaWrapsWhenAsked() {
		var ta = longTextArea();
		ta.wrap = true;
		Screen.instance.addComponent(ta);
		TestDriver.pump(3);
		var input = ta.getTextInput().inputNative;
		Assert.isTrue(input.ExtentWidth <= 150, 'extent ${input.ExtentWidth}');
		Assert.isTrue(input.ExtentHeight > 40, 'extent ${input.ExtentHeight}');
	}

	function testTextAreaWrapsByDefault() {
		// TextArea declares wrap = true, and html5 wraps every textarea
		var ta = longTextArea();
		Screen.instance.addComponent(ta);
		TestDriver.pump(3);
		var input = ta.getTextInput().inputNative;
		Assert.isTrue(input.ExtentWidth <= 150, 'extent ${input.ExtentWidth}');
	}

	function testTextAreaWithoutWrapScrollsSideways() {
		var ta = longTextArea();
		ta.wrap = false;
		Screen.instance.addComponent(ta);
		TestDriver.pump(3);
		var input = ta.getTextInput().inputNative;
		Assert.isTrue(input.ExtentWidth > 150, 'extent ${input.ExtentWidth}');
	}

	function testAutoFocusPicksTheFirstFocusable() {
		// html5 focuses the first focusable of a new view in child order; a TextArea last in
		// line must not take it (core sorts children by tab index, and ties keep their order).
		var view = new VBox();
		var list:ListView = ComponentBuilder.fromString('<listview width="150" height="90"><data><item text="Apple" /><item text="Banana" /></data></listview>');
		view.addComponent(list);
		view.addComponent(ComponentBuilder.fromString('<dropdown width="140" text="Pick"><data><item text="One" /></data></dropdown>'));
		var area = new TextArea();
		area.text = "words";
		view.addComponent(area);
		Screen.instance.addComponent(view);
		TestDriver.pump(4);
		Assert.isTrue(FocusManager.instance.focus == list, 'focus went to ${FocusManager.instance.focus}');
		Assert.isFalse(area.getTextInput().inputNative.IsFocused);
	}

	function testTabFollowsChildOrder() {
		var form = new VBox();
		var fields = [for (i in 0...5) new TextField()];
		for (f in fields) form.addComponent(f);
		Screen.instance.addComponent(form);
		TestDriver.pump(2);
		TestDriver.clickComponent(fields[0]);
		TestDriver.pump();
		for (i in 1...5) {
			TestDriver.key("Tab");
			TestDriver.pump(2);
			Assert.isTrue(FocusManager.instance.focus == fields[i], 'tab $i went to ${fields.indexOf(cast FocusManager.instance.focus)}');
		}
	}

	function testNativeFocusMatchesHaxeUIFocus() {
		// a list first, then a field, then an area made in code: the gallery's page
		var view = new VBox();
		var list = new ListView();
		var field = new TextField();
		var area = new TextArea();
		area.text = "made in code";
		view.addComponent(list);
		view.addComponent(field);
		view.addComponent(area);
		Screen.instance.addComponent(view);
		TestDriver.pump(3);
		for (c in ([field, area] : Array<InteractiveComponent>)) {
			Assert.equals(c.focus, c.getTextInput().inputNative.IsFocused, 'native focus of ${c.className}');
		}
		TestDriver.clickComponent(area);
		TestDriver.pump(2);
		Assert.isTrue(area.focus && area.getTextInput().inputNative.IsFocused);
		Assert.isFalse(field.getTextInput().inputNative.IsFocused);
	}

	static function longTextArea():TextArea {
		var ta = new TextArea();
		ta.width = 150;
		ta.height = 90;
		ta.text = "A textarea with enough words in it to wrap across several lines, and then some more.";
		return ta;
	}
}
