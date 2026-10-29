import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.backend.cs.AppLifecycle;
import haxe.ui.backend.cs.BackButton;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
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

			var tap = button("Tap me", 120, () -> Sys.println("android-app: clicked"));
			app.addComponent(tap);

			var open = button("Open", 180, () -> Dialogs.openFile((button, files) -> {
				if (button == DialogButton.OK) Sys.println('android-app: opened ${files[0].fullPath} ${files[0].bytes.length}');
				else Sys.println("android-app: open cancelled");
			}, {readContents: true, readAsBinary: true}));
			app.addComponent(open);

			var tip = button("Hold me", 240, () -> Sys.println("android-app: tip clicked"));
			tip.tooltip = "Tip";
			app.addComponent(tip);

			// Arms a back listener that takes the next back press, once.
			var trap = button("Trap back", 300, () -> {
				function once():Bool {
					BackButton.removeListener(once);
					Sys.println("android-app: back trapped");
					return true;
				}
				BackButton.addListener(once);
				Sys.println("android-app: back armed");
			});
			app.addComponent(trap);

			var field = new TextField();
			field.left = 40;
			field.top = 360;
			field.width = 200;
			app.addComponent(field);

			AppLifecycle.onPause = () -> Sys.println("android-app: paused");
			Screen.instance.registerEvent(UIEvent.RESIZE, _ -> Sys.println('android-app: resized ${size()}'));
			app.start();
			Sys.println('android-app: ready ${size()} scale ${Toolkit.scaleX}');

			// Where to tap, in device pixels, once everything has been laid out: "at <name> x y".
			haxe.ui.util.Timer.delay(() -> {
				var k = Toolkit.scaleX * Host.RenderScaling;
				for (c in [tap, open, tip, trap, field]) {
					var name = c == field ? "field" : c.text.split(" ")[0].toLowerCase();
					Sys.println('android-app: at $name ${Std.int((c.screenLeft + c.width / 2) * k)} ${Std.int((c.screenTop + c.height / 2) * k)}');
				}
			}, 500);

			// Reports a tooltip coming up, so the check can hold a finger down and look.
			var shown = false;
			new haxe.ui.util.Timer(100, () -> {
				var up = Lambda.exists(Screen.instance.rootComponents, c -> c.cssName == "tooltip" && !c.hidden);
				if (up && !shown) Sys.println("android-app: tooltip shown");
				shown = up;
			});
		});
	}

	static function button(text:String, top:Float, onClick:Void->Void):Button {
		var b = new Button();
		b.text = text;
		b.left = 40;
		b.top = top;
		b.onClick = _ -> onClick();
		return b;
	}

	static function size():String {
		return '${Std.int(Screen.instance.width)}x${Std.int(Screen.instance.height)}';
	}
}
