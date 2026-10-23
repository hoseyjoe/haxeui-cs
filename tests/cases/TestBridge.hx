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

	function testToolkitInits() {
		Assert.isTrue(Toolkit.initialized);
		Assert.equals(800.0, Screen.instance.width);
	}
}
