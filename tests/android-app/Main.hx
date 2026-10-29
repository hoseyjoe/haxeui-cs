import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.components.Label;
import haxe.ui.core.Screen;

/** The Android check's app: reports what the device gave it, as lines check-device.sh reads from logcat. **/
class Main {
	static function main() {
		var app = new HaxeUIApp();
		app.ready(function() {
			var label = new Label();
			label.text = "android-app";
			app.addComponent(label);
			app.start();
			Sys.println('android-app: ready ${Std.int(Screen.instance.width)}x${Std.int(Screen.instance.height)} scale ${Toolkit.scaleX}');
		});
	}
}
