package cases;

import haxe.ui.ToolkitAssets;
import haxe.ui.assets.ImageInfo;
import haxe.ui.components.Image;
import haxe.ui.constants.ScaleMode;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import haxe.ui.loaders.image.HttpImageLoader;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Images from resources and bytes, image scaling, and sliced background images. **/
class TestImages extends utest.Test {
	function setup() {
		sys.FileSystem.createDirectory("tests/bin/http");
		sys.io.File.copy("tests/assets/red4x4.png", "tests/bin/http/red.png");
	}

	function teardown() {
		TestDriver.stopHttpServer();
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
	}

	function testImageFromResource() {
		var image = new Image();
		image.resource = "red4x4.png";
		image.width = 40;
		image.height = 40;
		Screen.instance.addComponent(image);
		TestDriver.pump(3);
		Assert.equals(0xFFFF0000, TestDriver.pixel(20, 20));
	}

	function testImageFromBytes() {
		var info:ImageInfo = null;
		ToolkitAssets.instance.imageFromBytes(haxe.Resource.getBytes("red4x4.png"), i -> info = i);
		TestDriver.pump();
		Assert.notNull(info);
		Assert.equals(4, info.width);
		Assert.equals(4, info.height);
	}

	function testScaleModeFit() {
		var image = new Image();
		image.resource = "red4x4.png";
		image.width = 100;
		image.height = 40;
		image.scaleMode = ScaleMode.FIT_INSIDE;
		Screen.instance.addComponent(image);
		TestDriver.pump(3);
		Assert.equals(40.0, image.getImageDisplay().imageNative.W);
	}

	function testBackgroundSlice9() {
		var box = new Box();
		box.width = 200;
		box.height = 100;
		box.styleString = 'border-size: 0px; padding: 0px; background-image: "slice9.png"; '
			+ 'background-image-slice-left: 4px; background-image-slice-top: 4px; '
			+ 'background-image-slice-right: 8px; background-image-slice-bottom: 8px;';
		Screen.instance.addComponent(box);
		TestDriver.pump(3);
		Assert.equals(0xFF0000FF, TestDriver.pixel(1, 1), "corner");
		Assert.equals(0xFF00FF00, TestDriver.pixel(100, 1), "top edge");
		Assert.equals(0xFFFF0000, TestDriver.pixel(100, 50), "centre");
	}

	function testThemeIconLoads() {
		var info:ImageInfo = null;
		ToolkitAssets.instance.getImage("haxeui-core/styles/shared/down-arrow-dark.png", i -> info = i);
		TestDriver.pump();
		Assert.notNull(info);
	}

	function testHttpImageLoadsWithoutBlocking() {
		var port = TestDriver.startHttpServer("tests/bin/http");
		var got:ImageInfo = null, called = false;
		new HttpImageLoader().load('http://127.0.0.1:$port/red.png', info -> {
			called = true;
			got = info;
		});
		Assert.isFalse(called, "the load must not finish inside load()");
		pumpUntil(() -> called, 3000);
		Assert.isTrue(called);
		Assert.equals(4, got != null ? got.width : -1);
	}

	function testHttpImage404GivesNull() {
		var port = TestDriver.startHttpServer("tests/bin/http");
		var called = false, got:ImageInfo = null;
		new HttpImageLoader().load('http://127.0.0.1:$port/missing.png', info -> {
			called = true;
			got = info;
		});
		pumpUntil(() -> called, 3000);
		Assert.isTrue(called);
		Assert.isNull(got);
	}

	function testHttpImageUnreachableGivesNull() {
		var called = false, got:ImageInfo = null;
		new HttpImageLoader().load("http://127.0.0.1:1/none.png", info -> {
			called = true;
			got = info;
		});
		pumpUntil(() -> called, 5000);
		Assert.isTrue(called);
		Assert.isNull(got);
	}

	function testHttpImageAfterRemoval() {
		// the component goes away before the response arrives: nothing throws
		var port = TestDriver.startHttpServer("tests/bin/http");
		var image = new Image();
		image.resource = 'http://127.0.0.1:$port/red.png';
		Screen.instance.addComponent(image);
		Screen.instance.removeComponent(image);
		pumpFor(1000);
		Assert.pass();
	}

	static function pumpUntil(done:Void->Bool, ms:Int) {
		var end = haxe.Timer.stamp() + ms / 1000;
		while (!done() && haxe.Timer.stamp() < end) {
			TestDriver.pump();
		}
	}

	static function pumpFor(ms:Int) {
		pumpUntil(() -> false, ms);
	}
}
