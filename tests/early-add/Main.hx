import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.containers.Box;
import haxe.ui.core.Screen;

/**
 * A component added to the screen before the window exists (HaxeUIApp does
 * this with its preloader when a module declares preloads) must show once the
 * window does. Prints `early-add: ok` and exits 0, or says what it saw and exits 1.
 */
class Main {
	static function main() {
		var app = new HaxeUIApp();
		var early = new Box();
		early.left = 10;
		early.top = 10;
		early.width = 100;
		early.height = 40;
		early.styleString = "background-color: #FF0000;";
		Screen.instance.addComponent(early);
		app.ready(function() {
			TestDriver.pump(3);
			var p = TestDriver.pixel(50, 30);
			if (p == 0xFFFF0000) {
				Sys.println("early-add: ok");
				Host.Exit(0);
			}
			Sys.println('early-add: pixel (50, 30) is ${StringTools.hex(p, 8)}, wanted FFFF0000');
			Host.Exit(1);
		});
	}
}
