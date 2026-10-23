package cases;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Screen;
import utest.Assert;

class TestBridge extends utest.Test {
	function testHaxeImplementsCsInterface() {
		var hit = 0;
		Host.Post(Callbacks.callback(() -> hit++));
		TestDriver.pump();
		Assert.equals(1, hit);
	}

	function testResourcesEmbedded() {
		Assert.notNull(haxe.Resource.getString("haxeui_classmap"));
	}

	function testNestedResourcesEmbedded() {
		// a resource name with slashes is written to nested folders under Resources/
		Assert.notNull(haxe.Resource.getString("haxeui-core/styles/default/buttons.css"));
	}

	function testDefaultThemeLoaded() {
		Assert.isTrue(Toolkit.styleSheet.findMatchingRules(".button").length > 0);
	}

	function testWindowCaptureWritesPng() {
		// the desktop photograph (WindowCapture), usable headless too
		var path = "tests/bin/window-capture.png";
		if (sys.FileSystem.exists(path)) {
			sys.FileSystem.deleteFile(path);
		}
		Assert.isTrue(haxe.ui.backend.cs.WindowCapture.save(path));
		var bytes = sys.io.File.getBytes(path);
		Assert.isTrue(bytes.length > 100);
		Assert.equals(0x89, bytes.get(0)); // PNG signature
		Assert.equals("PNG", bytes.getString(1, 3));
	}

	function testToolkitInits() {
		Assert.isTrue(Toolkit.initialized);
		Assert.equals(800.0, Screen.instance.width);
	}
}
