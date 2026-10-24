package cases;

import haxe.ui.backend.cs.TestDriver;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.core.Screen;
import utest.Assert;

/**
 * Fonts by file: a `font-name` naming a .ttf as a Haxe resource or a file renders in that
 * font. DejaVu Sans Mono is monospaced, so "iiiiiiii" and "WWWWWWWW" measure the same in it
 * and very differently in the default proportional font.
 */
class TestFonts extends utest.Test {
	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testFontFromResource() {
		var s = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
		Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
		Assert.isTrue(width("WWWWWWWW", "font-size: 20px;") - width("iiiiiiii", "font-size: 20px;") > 20, "the default font is proportional");
	}

	function testFontFromRelativePath() {
		var s = "font-name: tests/assets/DejaVuSansMono.ttf; font-size: 20px;";
		Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
	}

	function testFontFromAbsolutePath() {
		var p = StringTools.replace(sys.FileSystem.absolutePath("tests/assets/DejaVuSansMono.ttf"), "\\", "/");
		var s = 'font-name: "$p"; font-size: 20px;';
		Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
	}

	function testBoldStillApplies() {
		var s = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
		Assert.isTrue(width("WWWW", s + " font-bold: true;") >= width("WWWW", s));
	}

	function testMissingFontFallsBack() {
		Assert.isTrue(width("Hello", "font-name: nowhere/missing.ttf;") > 0);
	}

	function testNotAFontFallsBack() {
		// a PNG resource named as a font
		Assert.isTrue(width("Hello", "font-name: red4x4.png;") > 0);
	}

	function testTextInputUsesFont() {
		var f = new TextField();
		f.styleString = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
		f.text = "iiiiiiii";
		Screen.instance.addComponent(f);
		TestDriver.pump(3);
		var narrow = f.getTextInput().textWidth;
		f.text = "WWWWWWWW";
		TestDriver.pump(3);
		Assert.floatEquals(narrow, f.getTextInput().textWidth, 1.0);
	}

	function testGenericMonospace() {
		var s = "font-name: monospace; font-size: 20px;";
		Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
	}

	function testGenericSerifDiffersFromSans() {
		var serif = width("Hamburgefonstiv", "font-name: serif; font-size: 20px;");
		var sans = width("Hamburgefonstiv", "font-name: sans-serif; font-size: 20px;");
		Assert.isTrue(Math.abs(serif - sans) > 2, 'serif $serif, sans-serif $sans');
	}

	static function width(text:String, style:String):Float {
		var l = new Label();
		l.styleString = style;
		l.text = text;
		Screen.instance.addComponent(l);
		TestDriver.pump(3);
		var w = l.width;
		Screen.instance.removeComponent(l);
		return w;
	}
}
