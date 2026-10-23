import haxe.ui.HaxeUIApp;
import haxe.ui.backend.cs.native.Native;
import utest.Runner;
import utest.ui.text.PlainTextReport;

class TestMain {
	static function main() {
		var app = new HaxeUIApp();
		app.ready(function() {
			var runner = new Runner();
			var only = haxe.macro.Compiler.getDefine("test");
			for (c in cases()) {
				if (only == null || only == "1" || Type.getClassName(Type.getClass(c)).split(".").pop() == only) {
					runner.addCase(c);
				}
			}
			var report = new PlainTextReport(runner);
			// utest picks these per target and has no case for C#.
			@:privateAccess report.newline = "\n";
			@:privateAccess report.indent = "  ";
			report.setHandler(function(r) {
				Sys.println(r.getResults());
				Host.Exit(@:privateAccess r.result.stats.isOk ? 0 : 1);
			});
			runner.run();
		});
	}

	static function cases():Array<utest.Test> {
		return [
			new cases.TestBridge(),
			new cases.TestCoreFixes(),
			new cases.TestLayout(),
			new cases.TestEventLoop(),
			new cases.TestStyles(),
			new cases.TestText(),
			new cases.TestImages(),
			new cases.TestMouse(),
			new cases.TestTextInput(),
			new cases.TestGraphics(),
			new cases.TestDialogs(),
			new cases.TestGallery(),
			new cases.TestKeys(),
			new cases.TestFonts(),
			new cases.TestFilters()
		];
	}
}
