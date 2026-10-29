import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.backend.cs.AppLifecycle;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.core.Screen;
import haxe.ui.events.UIEvent;

/** The Android check's app: reports what the device gave it, as lines check-device.sh reads from logcat. **/
class Main {
	static function main() {
		// One line per run of main, in the working directory: the files dir, so it outlives the process.
		var runs = sys.FileSystem.exists("runs.txt") ? sys.io.File.getContent("runs.txt") : "";
		runs += "run\n";
		sys.io.File.saveContent("runs.txt", runs);
		Sys.println('android-app: main ran ${runs.split("\n").length - 1} cwd ${haxe.io.Path.removeTrailingSlashes(Sys.getCwd())}');

		var app = new HaxeUIApp();
		app.ready(function() {
			var label = new Label();
			label.text = "android-app";
			app.addComponent(label);

			var button = new Button();
			button.text = "Tap me";
			button.left = 40;
			button.top = 120;
			button.onClick = _ -> Sys.println("android-app: clicked");
			app.addComponent(button);

			AppLifecycle.onPause = () -> Sys.println("android-app: paused");
			Screen.instance.registerEvent(UIEvent.RESIZE, _ -> Sys.println('android-app: resized ${size()}'));
			app.start();
			Sys.println('android-app: ready ${size()} scale ${Toolkit.scaleX}');

			// Where to tap, in device pixels, once the button has been laid out.
			haxe.ui.util.Timer.delay(() -> {
				var k = Toolkit.scaleX * Host.RenderScaling;
				Sys.println('android-app: button ${Std.int((button.screenLeft + button.width / 2) * k)} ${Std.int((button.screenTop + button.height / 2) * k)}');
			}, 500);
		});
	}

	static function size():String {
		return '${Std.int(Screen.instance.width)}x${Std.int(Screen.instance.height)}';
	}
}
