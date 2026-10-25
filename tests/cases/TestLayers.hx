package cases;

import haxe.io.Bytes;
import haxe.ui.Toolkit;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.components.Canvas;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import utest.Assert;

/** A canvas's retained layers (componentGraphics.layers): groups placed, faded and masked over bitmaps. **/
class TestLayers extends utest.Test {
	static inline var WHITE = 0xFFFFFFFF;
	static inline var RED = 0xFFFF0000;
	static inline var BLUE = 0xFF0000FF;

	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		if (Toolkit.scale != 1) {
			Toolkit.scale = 1;
			var reset = new Box(); // the scale is taken up as a root component is added
			Screen.instance.addComponent(reset);
			Screen.instance.removeComponent(reset);
		}
		TestDriver.pump();
	}

	/** Twice the pixels into the units: drawn where its rectangle says, at the group's units. **/
	function testBitmapDrawnIntoItsRectangle() {
		var layers = addCanvas().componentGraphics.layers;
		var b = layers.addBitmap();
		layers.setPixels(b, solid(20, 20, RED), 20, 20, 10, 10, 10, 10);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(15, 15));
		Assert.equals(WHITE, TestDriver.pixel(25, 15), "past its rectangle");
		Assert.equals(WHITE, TestDriver.pixel(5, 5));
	}

	/** A group's matrix moves and scales what is in it, without new pixels. **/
	function testGroupMatrixPlacesItsBitmaps() {
		var layers = addCanvas().componentGraphics.layers;
		var g = layers.addGroup();
		var b = layers.addBitmap(g);
		layers.setPixels(b, solid(10, 10, RED), 10, 10, 0, 0, 10, 10);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(5, 5));
		layers.setMatrix(g, 2, 0, 0, 2, 40, 20);
		TestDriver.pump(2);
		Assert.equals(WHITE, TestDriver.pixel(5, 5), "moved away");
		Assert.equals(RED, TestDriver.pixel(55, 35), "scaled 2x from 40, 20");
		Assert.equals(WHITE, TestDriver.pixel(62, 42), "past the scaled bitmap");
	}

	/** Groups nest: a child group's matrix is in its parent's units. **/
	function testNestedGroups() {
		var layers = addCanvas().componentGraphics.layers;
		var outer = layers.addGroup();
		var inner = layers.addGroup(outer);
		var b = layers.addBitmap(inner);
		layers.setPixels(b, solid(10, 10, BLUE), 10, 10, 0, 0, 10, 10);
		layers.setMatrix(outer, 2, 0, 0, 2, 0, 0);
		layers.setMatrix(inner, 1, 0, 0, 1, 20, 10);
		TestDriver.pump(2);
		Assert.equals(BLUE, TestDriver.pixel(45, 25), "at (20, 10) of the outer group's units, 2x");
		Assert.equals(WHITE, TestDriver.pixel(25, 15));
	}

	/** A fading group is one image: two overlapping bitmaps in it are no darker where they overlap. **/
	function testGroupFadesAsOneImage() {
		var layers = addCanvas().componentGraphics.layers;
		var g = layers.addGroup();
		var a = layers.addBitmap(g);
		var b = layers.addBitmap(g);
		layers.setPixels(a, solid(40, 20, RED), 40, 20, 0, 0, 40, 20);
		layers.setPixels(b, solid(40, 20, RED), 40, 20, 20, 0, 40, 20);
		layers.setOpacity(g, 0.5);
		TestDriver.pump(2);
		var alone = TestDriver.pixel(10, 10);
		var overlap = TestDriver.pixel(30, 10);
		Assert.isTrue(near(0xFFFF8080, alone), "half red over white: " + StringTools.hex(alone));
		Assert.equals(alone, overlap, "the overlap is the same colour");
	}

	/** A group's mask lets through only where it is opaque, and nothing outside its rectangle. **/
	function testGroupMask() {
		var layers = addCanvas().componentGraphics.layers;
		var g = layers.addGroup();
		var b = layers.addBitmap(g);
		layers.setPixels(b, solid(100, 100, RED), 100, 100, 0, 0, 100, 100);
		// left half opaque, right half clear, over 20..80 of the group
		var mask = Bytes.alloc(60 * 60 * 4);
		for (y in 0...60) for (x in 0...30) mask.setInt32((y * 60 + x) * 4, 0xFFFFFFFF);
		layers.setPixels(g, mask, 60, 60, 20, 20, 60, 60);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(35, 50), "under the mask's opaque half");
		Assert.equals(WHITE, TestDriver.pixel(65, 50), "under its clear half");
		Assert.equals(WHITE, TestDriver.pixel(10, 10), "outside the mask");
		layers.setPixels(g, null, 0, 0, 0, 0, 0, 0);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(10, 10), "mask removed");
	}

	function testHiddenAndCleared() {
		var layers = addCanvas().componentGraphics.layers;
		var b = layers.addBitmap();
		layers.setPixels(b, solid(10, 10, RED), 10, 10, 0, 0, 10, 10);
		layers.setVisible(b, false);
		TestDriver.pump(2);
		Assert.equals(WHITE, TestDriver.pixel(5, 5));
		layers.setVisible(b, true);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(5, 5));
		layers.clear();
		TestDriver.pump(2);
		Assert.equals(0, layers.count);
		Assert.equals(WHITE, TestDriver.pixel(5, 5));
	}

	/** The canvas's own drawing is under its layers. **/
	function testAboveCanvasDrawing() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.fillStyle(0x0000FF);
		g.rectangle(0, 0, 100, 100);
		g.fillStyle(null);
		var b = g.layers.addBitmap();
		g.layers.setPixels(b, solid(10, 10, RED), 10, 10, 0, 0, 10, 10);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(5, 5));
		Assert.equals(BLUE, TestDriver.pixel(50, 50));
	}

	/** A colour filter on the canvas reaches its layers, as it reaches its drawing. **/
	function testColourFilter() {
		var canvas = addCanvas();
		canvas.styleString = "filter: grayscale;";
		var b = canvas.componentGraphics.layers.addBitmap();
		canvas.componentGraphics.layers.setPixels(b, solid(10, 10, RED), 10, 10, 0, 0, 10, 10);
		TestDriver.pump(2);
		var p = TestDriver.pixel(5, 5);
		Assert.isTrue(near(0xFF363636, p), "red in grey: " + StringTools.hex(p));
	}

	function testDeviceScaleFollowsToolkitScale() {
		var layers = addCanvas().componentGraphics.layers;
		var base = layers.deviceScale;
		Assert.isTrue(base >= 1, "the screen's own scale: " + base);
		Screen.instance.removeComponent(Screen.instance.rootComponents[0]);
		Toolkit.scale = 2;
		var scaled = addCanvas().componentGraphics.layers;
		Assert.floatEquals(base * 2, scaled.deviceScale);
	}

	static function addCanvas():Canvas {
		var canvas = new Canvas();
		canvas.width = 100;
		canvas.height = 100;
		Screen.instance.addComponent(canvas);
		TestDriver.pump(2);
		return canvas;
	}

	/** w x h RGBA pixels of one ARGB colour. **/
	static function solid(w:Int, h:Int, argb:Int):Bytes {
		var out = Bytes.alloc(w * h * 4);
		for (i in 0...w * h) {
			out.set(i * 4, (argb >> 16) & 0xFF);
			out.set(i * 4 + 1, (argb >> 8) & 0xFF);
			out.set(i * 4 + 2, argb & 0xFF);
			out.set(i * 4 + 3, (argb >>> 24) & 0xFF);
		}
		return out;
	}

	static function near(expected:Int, actual:Int):Bool {
		for (shift in [0, 8, 16, 24]) {
			if (Math.abs(((expected >>> shift) & 0xFF) - ((actual >>> shift) & 0xFF)) > 3) {
				return false;
			}
		}
		return true;
	}
}
