package cases;

import haxe.ui.components.Label;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.styles.StyleSheet;
import haxe.ui.styles.elements.RuleElement;
import utest.Assert;

/** Which rules of a style sheet apply to a component, as what the component is changes. **/
class TestStyleSheet extends utest.Test {
	static function sheet(css:String):StyleSheet {
		var s = new StyleSheet();
		s.parse(css);
		return s;
	}

	static function colourOf(s:StyleSheet, c:Component):Null<Int> {
		return s.buildStyleFor(c).color;
	}

	function testRulesApplyInTheOrderTheyWereWritten() {
		var s = sheet("box { color: #000001; } .a { color: #000002; } box { color: #000003; } .b { color: #000004; }");
		var box = new Box();
		Assert.equals(0x000003, colourOf(s, box));
		box.addClass("a");
		Assert.equals(0x000003, colourOf(s, box));
		box.addClass("b");
		Assert.equals(0x000004, colourOf(s, box));
	}

	function testAClassCountsFromWhenItIsAddedUntilItIsRemoved() {
		var s = sheet(".a { color: #000001; }");
		var box = new Box();
		Assert.isNull(colourOf(s, box));
		box.addClass("a");
		Assert.equals(0x000001, colourOf(s, box));
		box.removeClass("a");
		Assert.isNull(colourOf(s, box));
	}

	function testAComponentNeedsEveryClassOfARule() {
		var s = sheet(".a.b { color: #000001; }");
		var box = new Box();
		box.addClass("a");
		Assert.isNull(colourOf(s, box));
		box.addClass("b");
		Assert.equals(0x000001, colourOf(s, box));
	}

	function testAPseudoClassIsAClass() {
		var s = sheet("box:hover { color: #000001; } .a:down { color: #000002; }");
		var box = new Box();
		Assert.isNull(colourOf(s, box));
		box.addClass(":hover");
		Assert.equals(0x000001, colourOf(s, box));
		box.addClass("a");
		Assert.equals(0x000001, colourOf(s, box));
		box.addClass(":down");
		Assert.equals(0x000002, colourOf(s, box));
	}

	function testAnIdCountsFromWhenItIsGiven() {
		var s = sheet("#one { color: #000001; } #two { color: #000002; }");
		var box = new Box();
		Assert.isNull(colourOf(s, box));
		box.id = "one";
		Assert.equals(0x000001, colourOf(s, box));
		box.id = "two";
		Assert.equals(0x000002, colourOf(s, box));
		box.id = "three";
		Assert.isNull(colourOf(s, box));
		box.id = "one";
		Assert.equals(0x000001, colourOf(s, box));
	}

	function testComponentsOfDifferentKindsAreToldApart() {
		var s = sheet("box { color: #000001; } label { color: #000002; }");
		Assert.equals(0x000001, colourOf(s, new Box()));
		Assert.equals(0x000002, colourOf(s, new Label()));
		Assert.equals(0x000001, colourOf(s, new Box()));
	}

	function testTheWildcardAppliesToEverything() {
		var s = sheet("* { color: #000001; } .a { color: #000002; }");
		Assert.equals(0x000001, colourOf(s, new Box()));
		var label = new Label();
		label.addClass("a");
		Assert.equals(0x000002, colourOf(s, label));
	}

	function testAnAncestorCountsWhereverTheComponentIs() {
		var s = sheet(".outer .inner { color: #000001; } .parent > .inner { color: #000002; }");
		var inner = new Box();
		inner.addClass("inner");
		Assert.isNull(colourOf(s, inner));

		var outer = new Box();
		outer.addClass("outer");
		var middle = new Box();
		outer.addComponent(middle);
		middle.addComponent(inner);
		Assert.equals(0x000001, colourOf(s, inner), "an ancestor, not only the parent");

		// The same class on the same component, with nothing else about it changed, under another parent.
		middle.removeComponent(inner, false);
		Assert.isNull(colourOf(s, inner));
		var parent = new Box();
		parent.addClass("parent");
		parent.addComponent(inner);
		Assert.equals(0x000002, colourOf(s, inner));

		parent.removeClass("parent");
		Assert.isNull(colourOf(s, inner), "a change to the parent alone");
	}

	function testRulesAddedAfterAStyleWasBuiltCount() {
		var s = sheet(".a { color: #000001; }");
		var box = new Box();
		box.addClass("a");
		Assert.equals(0x000001, colourOf(s, box));

		s.parse(".a { color: #000002; }");
		Assert.equals(0x000002, colourOf(s, box), "parse");

		s.addRule(new RuleElement(".a", [new haxe.ui.styles.elements.Directive("color", haxe.ui.styles.Value.VColor(0x000003))]));
		Assert.equals(0x000003, colourOf(s, box), "addRule");

		s.merge(sheet(".a { color: #000004; }"));
		Assert.equals(0x000004, colourOf(s, box), "merge");
	}

	function testRulesRemovedAfterAStyleWasBuiltDoNot() {
		var s = sheet(".a { color: #000001; } .b { color: #000002; }");
		var box = new Box();
		box.addClass("a");
		box.addClass("b");
		Assert.equals(0x000002, colourOf(s, box));

		s.removeRule(".b");
		Assert.equals(0x000001, colourOf(s, box), "removeRule");

		s.removeAllRules();
		Assert.isNull(colourOf(s, box), "removeAllRules");

		s.parse(".a { color: #000003; }");
		Assert.equals(0x000003, colourOf(s, box));
		s.clear();
		Assert.isNull(colourOf(s, box), "clear");
	}

	function testAMediaQueryComesAfterItsSheetsOwnRulesWhenItIsRelevant() {
		var s = sheet("@media (min-width: 1px) { .a { color: #000001; } } @media (min-width: 100000px) { .a { color: #000002; } } .a { color: #000003; }");
		var box = new Box();
		box.addClass("a");
		Assert.equals(0x000001, colourOf(s, box));
	}

	function testASheetsRulesAreItsOwn() {
		var a = sheet(".a { color: #000001; }");
		var b = sheet(".a { color: #000002; }");
		var box = new Box();
		box.addClass("a");
		Assert.equals(0x000001, colourOf(a, box));
		Assert.equals(0x000002, colourOf(b, box));
		Assert.equals(0x000001, colourOf(a, box));
	}
}
