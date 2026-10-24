package cases;

import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.native.Native;
import utest.Assert;

/** The app's own settings that reach the window. **/
class TestApp extends utest.Test {
	function testIcon() {
		HaxeUIApp.instance.icon = "red4x4.png";
		Assert.isTrue(Host.HasIcon);
	}
}
