package cases;

import haxe.ui.ToolkitAssets;
import haxe.ui.assets.ImageInfo;
import haxe.ui.components.Image;
import haxe.ui.constants.ScaleMode;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Images from resources and bytes, image scaling, and sliced background images. **/
class TestImages extends utest.Test {
	function teardown() {
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
}
