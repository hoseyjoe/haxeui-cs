package cases;

import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.WindowBackground;
import haxe.ui.backend.cs.WindowClose;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Screen;
import utest.Assert;

/** The app's own settings that reach the window. **/
class TestApp extends utest.Test {
	function testIcon() {
		HaxeUIApp.instance.icon = "red4x4.png";
		Assert.isTrue(Host.HasIcon);
	}

	function testBackground() {
		for (c in Screen.instance.rootComponents.copy()) {
			Screen.instance.removeComponent(c);
		}
		TestDriver.pump();
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(5, 5), "white until an app says otherwise");
		WindowBackground.set(0x1f2123);
		TestDriver.pump();
		Assert.equals(0xFF1F2123, TestDriver.pixel(5, 5), "a dark theme's background");
		WindowBackground.set(0xFFFFFF);
		TestDriver.pump();
		Assert.equals(0xFFFFFFFF, TestDriver.pixel(5, 5), "and back");
	}

	function teardown() {
		WindowClose.onRequest = null;
	}

	function testCloseRefused() {
		var asked = 0;
		WindowClose.onRequest = function() {
			asked++;
			return false;
		};
		// as the close button does: a close the app did not ask for
		cs.Syntax.code("HaxeUICs.Host.Window.Close()");
		TestDriver.pump();
		Assert.equals(1, asked);
		Assert.isTrue(cs.Syntax.code("HaxeUICs.Host.Window.IsVisible"), "the window stays open");
	}

	function testCloseAllowed() {
		Assert.isTrue(Host.AskClose(), "no handler: it closes");
		WindowClose.onRequest = () -> true;
		Assert.isTrue(Host.AskClose());
		WindowClose.onRequest = () -> false;
		Assert.isFalse(Host.AskClose());
		WindowClose.onRequest = () -> throw "boom";
		Assert.isTrue(Host.AskClose(), "a handler that throws can't keep the window open");
	}
}
