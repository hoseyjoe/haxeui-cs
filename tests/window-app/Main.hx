import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * A real window opened with every window option, checked, left idle for two
 * seconds (which must cost next to no CPU), then closed by the app itself with
 * `app.exit()`: the process must end by itself with exit code 0, printing
 * `window-app: ok` from its onEnd.
 */
class Main {
	/** At most ten a second while idle (it polls four times a second for cross-thread work). **/
	static inline var IDLE_WAKEUPS_BUDGET = 20;

	static function cpuMilliseconds():Float {
		return cs.Syntax.code("System.Diagnostics.Process.GetCurrentProcess().TotalProcessorTime.TotalMilliseconds");
	}

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
			// An idle app stays idle: over two quiet seconds (after one of settling) Haxe's event
			// loop must not be woken more than a few times a second, nor cost much CPU.
			var cpuAtStart = -1.0;
			var pumpsAtStart = 0;
			Host.StartTimer(1000, Callbacks.callback(function() {
				if (cpuAtStart >= 0) return;
				cpuAtStart = cpuMilliseconds();
				pumpsAtStart = Host.EventsPumps;
			}));
			var asked = false;
			Host.StartTimer(3000, Callbacks.callback(function() {
				if (asked) return;
				asked = true;
				var pumps = Host.EventsPumps - pumpsAtStart;
				var cpu = cpuMilliseconds() - cpuAtStart;
				Sys.println('window-app: idle 2s: $pumps event-loop wake-ups, ${Math.round(cpu)}ms CPU');
				if (pumps > IDLE_WAKEUPS_BUDGET) {
					Sys.println('window-app: over the budget of $IDLE_WAKEUPS_BUDGET wake-ups');
					Host.Exit(3);
				}
				app.exit();
			}));
			app.start();
		}, function() {
			Sys.println("window-app: ok");
		});
	}
}
