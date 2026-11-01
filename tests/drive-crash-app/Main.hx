import haxe.Timer;
import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.native.Native.AppDriver;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * Without arguments: the check. It runs this program as a child twice, with `timer` and `host`, and
 * wants each to die by itself, non-zero, with its error on stderr. With one of those arguments: the
 * app that throws, once its window is up. In a driven build the error must end the process (Avalonia
 * would swallow it, and the app would sit there with no event loop and no word).
 */
class Main {
	static inline var LIMIT_SECONDS = 10.0;
	static inline var MESSAGE = "deliberate error from ";

	static function main() {
		var args = Sys.args();
		if (args.length == 0) {
			check();
			return;
		}
		AppDriver.SetWindow(true);
		var app = new HaxeUIApp({width: 320, height: 240, title: "drive-crash-app"});
		app.ready(function() {
			app.start();
			if (args[0] == "timer") {
				Timer.delay(() -> throw MESSAGE + "a haxe.Timer", 300);
			} else {
				Host.StartTimer(300, Callbacks.callback(() -> throw MESSAGE + "Host.StartTimer"));
			}
		});
	}

	static function check() {
		var failed = false;
		for (mode in ["timer", "host"]) {
			var child = new sys.io.Process("dotnet", [Sys.programPath(), mode]);
			var started = Sys.time();
			var code:Null<Int> = null;
			while (code == null && Sys.time() - started < LIMIT_SECONDS) {
				code = child.exitCode(false);
				Sys.sleep(0.05);
			}
			if (code == null) {
				child.kill();
				Sys.println('drive-crash-app: FAILED, "$mode" was still running after ${LIMIT_SECONDS}s (killed)');
				failed = true;
				continue;
			}
			var err = child.stderr.readAll().toString();
			if (code == 0) {
				Sys.println('drive-crash-app: FAILED, "$mode" exited 0');
				failed = true;
			} else if (err.indexOf(MESSAGE) < 0) {
				Sys.println('drive-crash-app: FAILED, "$mode" exited $code without its error on stderr: $err');
				failed = true;
			} else {
				Sys.println('drive-crash-app: "$mode" died by itself with exit code $code in ${Math.round((Sys.time() - started) * 1000)} ms, its error on stderr');
			}
		}
		if (failed) {
			Sys.exit(1);
		}
		Sys.println("drive-crash-app: ok");
	}
}
