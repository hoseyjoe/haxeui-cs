import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * Opens a real window, runs a repeating haxe.Timer, and closes the window
 * after half a second. Prints how often the haxe.Timer ticked; the process
 * must then end by itself, with exit code 0.
 */
class Main {
	static function main() {
		var app = new HaxeUIApp();
		app.ready(function() {
			var ticks = 0;
			var timer = new haxe.Timer(50);
			timer.run = () -> ticks++;
			var closed = false;
			Host.StartTimer(500, Callbacks.callback(function() {
				if (closed) return;
				closed = true;
				Sys.println('exit-app: haxe.Timer ticks=$ticks');
				Host.CloseWindow();
			}));
			app.start();
		});
	}
}
