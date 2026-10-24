package cases;

import haxe.ui.components.Canvas;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** HaxeUI canvas drawing, with haxeui-heaps' Flash-style fill semantics. **/
class TestGraphics extends utest.Test {
	static inline var WHITE = 0xFFFFFFFF;
	static inline var RED = 0xFFFF0000;
	static inline var BLUE = 0xFF0000FF;

	function teardown() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testFillWithoutBeginPath() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.fillStyle(0xFF0000);
		g.moveTo(10, 10);
		g.lineTo(90, 10);
		g.lineTo(50, 90);
		g.fillStyle(null);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(50, 30));
	}

	function testFillEndsAtNull() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.fillStyle(0xFF0000);
		g.moveTo(10, 10);
		g.lineTo(40, 10);
		g.lineTo(25, 40);
		g.fillStyle(null);
		g.moveTo(50, 50);
		g.lineTo(90, 50);
		g.lineTo(70, 90);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(25, 18));
		Assert.equals(WHITE, TestDriver.pixel(70, 60));
	}

	function testStrokeOnly() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.strokeStyle(0x0000FF, 4);
		g.moveTo(0, 50);
		g.lineTo(100, 50);
		TestDriver.pump(2);
		Assert.equals(BLUE, TestDriver.pixel(50, 50));
		Assert.equals(WHITE, TestDriver.pixel(50, 30));
	}

	function testCircleAndRectangleFill() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.fillStyle(0xFF0000);
		g.circle(25, 25, 15);
		g.fillStyle(0x0000FF);
		g.rectangle(60, 60, 30, 30);
		g.fillStyle(null);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(25, 25));
		Assert.equals(BLUE, TestDriver.pixel(75, 75));
		Assert.equals(WHITE, TestDriver.pixel(25, 75));
	}

	function testClearRemovesDrawing() {
		var canvas = addCanvas();
		var g = canvas.componentGraphics;
		g.fillStyle(0xFF0000);
		g.rectangle(0, 0, 100, 100);
		g.fillStyle(null);
		TestDriver.pump(2);
		Assert.equals(RED, TestDriver.pixel(50, 50));
		g.clear();
		TestDriver.pump(2);
		Assert.equals(WHITE, TestDriver.pixel(50, 50));
	}

	function testSetPixel() {
		var canvas = addCanvas();
		canvas.componentGraphics.setPixel(5, 5, 0xFF0000);
		TestDriver.pump(3);
		Assert.equals(RED, TestDriver.pixel(5, 5));
		Assert.notEquals(RED, TestDriver.pixel(6, 5));
	}

	static function addCanvas():Canvas {
		var canvas = new Canvas();
		canvas.width = 100;
		canvas.height = 100;
		Screen.instance.addComponent(canvas);
		TestDriver.pump(2);
		return canvas;
	}
}
