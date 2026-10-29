import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.Clipboard;
import haxe.ui.backend.cs.WindowClose;
import haxe.ui.backend.cs.native.Native.Host;

/** Win32Clipboard.cs: the clipboard as another program reads it. **/
@:native("ClipboardApp.Win32Clipboard")
extern class Win32Clipboard {
	static function Format(name:String):String;
}

/**
 * The OS clipboard (headless tests only see Avalonia's in-memory one) and the close guard, in a
 * real window: text goes onto the clipboard and comes back, a clear empties it, sensitive text
 * carries Windows' marks and stays out of clipboard history (Win+V) while plain text goes in, a
 * close the app did not ask for is put to `WindowClose.onRequest` and refused, and `app.exit()`
 * then closes without asking. Exits 0 printing `clipboard-app: ok` and, last, the text it leaves
 * behind.
 */
class Main {
	/** How long the history service is given to take a copy, if it is going to. **/
	static inline var HISTORY_WAIT_MS = 1500;

	static final SENSITIVE = [
		"ExcludeClipboardContentFromMonitorProcessing",
		"CanIncludeInClipboardHistory",
		"CanUploadToCloudClipboard"
	];

	static function fail(code:Int, what:String):Void {
		Sys.println('clipboard-app: $what');
		Host.Exit(code);
	}

	/**
	 * Asks tests/clipboard-app/history.ps1 (Windows PowerShell, which reads WinRT's clipboard
	 * history) whether `present` is in the history and `absent` is not: null if so or if history
	 * can't be checked here (said why), otherwise what is wrong.
	 */
	static function checkHistory(present:String, absent:String):Null<String> {
		var script = "tests/clipboard-app/history.ps1";
		var ps = new sys.io.Process("powershell.exe", [
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, "-Present", present, "-Absent", absent
		]);
		var said = StringTools.trim(ps.stdout.readAll().toString());
		var code = ps.exitCode();
		ps.close();
		Sys.println(said);
		return switch code {
			case 0: null;
			case 2: Sys.println("clipboard-app: clipboard history not checked"); null;
			case _: 'history check failed ($code)';
		}
	}

	static function main() {
		var app = new HaxeUIApp({width: 320, height: 200, title: "clipboard-app"});
		var asked = 0;
		var stamp = Std.int(Sys.time());
		var left = 'haxeui-cs clipboard-app $stamp';
		var secret = 'haxeui-cs clipboard-app secret $stamp';
		var windows = Sys.systemName() == "Windows";
		app.ready(function() {
			var started = false;
			Host.StartTimer(500, Callbacks.callback(function() {
				if (started) return;
				started = true;
				var text = "päss € \u{1F511}";
				if (!Clipboard.setText(text)) return fail(2, "setText failed");
				var back = Clipboard.getText();
				if (back != text) return fail(3, 'read back "$back"');
				if (!Clipboard.clear()) return fail(4, "clear failed");
				var after = Clipboard.getText();
				if (after != null) return fail(5, 'after clear: "$after"');

				if (!Clipboard.setText(secret, true)) return fail(9, "sensitive setText failed");
				var backSecret = Clipboard.getText(); // at once, while history may still hold the clipboard open
				if (backSecret != secret) return fail(10, 'sensitive read back "$backSecret"');
				for (name in SENSITIVE) {
					var held = Win32Clipboard.Format(name);
					if (held != (windows ? "00000000" : null)) return fail(11, '$name holds $held');
				}

				WindowClose.onRequest = function() {
					asked++;
					return false;
				};
				cs.Syntax.code("HaxeUICs.Host.Window.Close()"); // as the close button does
				if (asked != 1) return fail(6, 'the guard was asked $asked times');
				if (!cs.Syntax.code("HaxeUICs.Host.Window.IsVisible")) return fail(7, "the window closed though refused");

				// The secret stays on long enough for history to take it, were it going to.
				haxe.Timer.delay(function() {
					Clipboard.setText(left);
					haxe.Timer.delay(function() {
						if (windows) {
							var wrong = checkHistory(left, secret);
							if (wrong != null) return fail(12, wrong);
						}
						app.exit(); // must not ask
					}, HISTORY_WAIT_MS);
				}, HISTORY_WAIT_MS);
			}));
			app.start();
		}, function() {
			if (asked != 1) {
				Sys.println('clipboard-app: app.exit() asked the guard (asked $asked times)');
				Host.Exit(8);
			}
			Sys.println("clipboard-app: ok");
			Sys.println(left);
		});
	}
}
