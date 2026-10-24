import haxe.ui.HaxeUIApp;
import haxe.ui.components.Label;
import haxe.ui.core.Screen;
import haxe.ui.events.KeyboardEvent;

/**
 * A by-hand check of keys: prints each key's code and modifiers as HaxeUI sees it.
 * On a Mac, Cmd+S must print `keys-app: 83 ctrl=true`. Escape closes the window.
 */
class Main {
	static function main() {
		var app = new HaxeUIApp({width: 480, height: 160, title: "keys-app"});
		app.ready(function() {
			var hint = new Label();
			hint.text = "Press keys (Cmd+S on a Mac). Escape closes.";
			hint.left = 20;
			hint.top = 20;
			Screen.instance.addComponent(hint);
			Screen.instance.registerEvent(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
				Sys.println('keys-app: ${e.keyCode} ctrl=${e.ctrlKey} shift=${e.shiftKey} alt=${e.altKey}');
				if (e.keyCode == 27) {
					app.exit();
				}
			});
			app.start();
		});
	}
}
