import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.Callbacks;
import haxe.ui.backend.cs.Clipboard;
import haxe.ui.backend.cs.WindowClose;
import haxe.ui.backend.cs.native.Native.Host;

/**
 * The OS clipboard (headless tests only see Avalonia's in-memory one) and the close guard, in a
 * real window: text goes onto the clipboard and comes back, a clear empties it, a close the app
 * did not ask for is put to `WindowClose.onRequest` and refused, and `app.exit()` then closes
 * without asking. Exits 0 printing `clipboard-app: ok` and, last, the text it leaves behind.
 */
class Main {
	static function fail(code:Int, what:String):Void {
		Sys.println('clipboard-app: $what');
		Host.Exit(code);
	}

	static function main() {
		var app = new HaxeUIApp({width: 320, height: 200, title: "clipboard-app"});
		var asked = 0;
		var left = 'haxeui-cs clipboard-app ${Std.int(Sys.time())}';
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

				WindowClose.onRequest = function() {
					asked++;
					return false;
				};
				cs.Syntax.code("HaxeUICs.Host.Window.Close()"); // as the close button does
				if (asked != 1) return fail(6, 'the guard was asked $asked times');
				if (!cs.Syntax.code("HaxeUICs.Host.Window.IsVisible")) return fail(7, "the window closed though refused");

				Clipboard.setText(left);
				app.exit(); // must not ask
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
