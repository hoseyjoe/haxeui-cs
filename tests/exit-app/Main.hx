import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * Opens a real window, runs a repeating haxe.Timer, and closes the window
 * after half a second. Prints how often the haxe.Timer ticked; the process
 * must then end by itself, with exit code 0.
 *
 * With `--throw-on-end` the app's onEnd throws: the process must still end,
 * with the failure reported and exit code 1 (never a hang, never a quiet 0).
 */
class Main {
	static function main() {
		var app = new HaxeUIApp({width: 640, height: 480, title: "exit-app"});
		app.ready(function() {
			// the window must be what the options asked for
			if (Host.ClientWidth != 640 || Host.ClientHeight != 480 || Host.Title != "exit-app") {
				Sys.println('exit-app: window is ${Host.ClientWidth}x${Host.ClientHeight} "${Host.Title}", wanted 640x480 "exit-app"');
				Host.Exit(2);
			}
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
		}, function() {
			if (Sys.args().indexOf("--throw-on-end") != -1) {
				throw "deliberate failure in onEnd";
			}
		});
	}
}
