import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.components.Label;

/** The hxc build's check: a Label through a whole frame, and an embedded resource. See check.sh. **/
class App {
	static function main() {
		var app = new HaxeUIApp();
		app.ready(function() {
			var label = new Label();
			label.text = "ready";
			app.addComponent(label);
			app.start();
			TestDriver.pump();
			Sys.println(StringTools.trim(haxe.Resource.getString("note")));
			Sys.println(label.text);
			Sys.exit(0);
		});
	}
}
