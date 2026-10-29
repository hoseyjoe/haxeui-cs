package cases;

import haxe.ui.components.Image;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.SvgPalette;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** SVG images recoloured by SvgPalette, as heaps-svg's SvgIcons.setPalette recolours them. **/
class TestSvgPalette extends utest.Test {
	function teardown() {
		SvgPalette.set(null);
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testImageOnScreenRecoloured() {
		var img = new Image();
		img.resource = "square.svg"; // fill="#ff0000"
		img.width = 40;
		img.height = 40;
		Screen.instance.addComponent(img);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(20, 20), "as authored");
		SvgPalette.set([0xFF0000 => 0x0000FF]);
		TestDriver.pump(3);
		Assert.equals(0xFF0000FF, TestDriver.pixel(20, 20), "already on screen, redrawn");
		SvgPalette.set(null);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(20, 20), "back as authored");
	}

	function testImageAddedAfter() {
		SvgPalette.set([0xFF0000 => 0x00FF00]);
		var img = new Image();
		img.resource = "square.svg";
		img.width = 40;
		img.height = 40;
		Screen.instance.addComponent(img);
		TestDriver.pump(3);
		Assert.equals(0xFF00FF00, TestDriver.pixel(20, 20));
	}

	function testShortHexAndOtherColoursKept() {
		// #f00 is red too; #00ff00 is not in the palette
		var img = new Image();
		img.resource = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="10" height="10" fill="#f00"/><rect x="10" width="10" height="10" fill="#00ff00"/></svg>';
		img.width = 40;
		img.height = 20;
		Screen.instance.addComponent(img);
		SvgPalette.set([0xFF0000 => 0x0000FF]);
		TestDriver.pump(3);
		Assert.equals(0xFF0000FF, TestDriver.pixel(10, 10), "#f00 mapped");
		Assert.equals(0xFF00FF00, TestDriver.pixel(30, 10), "a colour not in the palette is kept");
	}

	function testBackgroundImageRecoloured() {
		var b = new Box();
		b.width = 100;
		b.height = 60;
		b.styleString = 'border-size: 0px; padding: 0px; background-image: "square.svg";';
		Screen.instance.addComponent(b);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
		SvgPalette.set([0xFF0000 => 0x0000FF]);
		TestDriver.pump(3);
		Assert.equals(0xFF0000FF, TestDriver.pixel(50, 30));
	}
}
