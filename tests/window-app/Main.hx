import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * A real window opened with every window option, checked, then closed by the
 * app itself with `app.exit()`: the process must end by itself with exit code 0,
 * printing `window-app: ok` from its onEnd.
 */
class Main {
	static function main() {
		var app = new HaxeUIApp({
			width: 640,
			height: 480,
			title: "window-app",
			resizable: false,
			minWidth: 300,
			minHeight: 200,
			maximized: false
		});
		app.ready(function() {
			if (Host.IsResizable || Host.MinWidth != 300 || Host.MinHeight != 200 || Host.IsMaximized) {
				Sys.println('window-app: resizable=${Host.IsResizable} min=${Host.MinWidth}x${Host.MinHeight} maximized=${Host.IsMaximized}');
				Host.Exit(2);
			}
			var asked = false;
			Host.StartTimer(300, Callbacks.callback(function() {
				if (asked) return;
				asked = true;
				app.exit();
			}));
			app.start();
		}, function() {
			Sys.println("window-app: ok");
		});
	}
}
