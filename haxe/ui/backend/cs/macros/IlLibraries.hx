package haxe.ui.backend.cs.macros;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

/**
 * Avalonia for hxc's `-D dotnet`, which writes the app's .dll itself and has no `dotnet build` to
 * fetch anything. `prepare` builds an empty app of the same name once, in a cache beside the
 * library and never in the app's folders, for what only a build makes: the libraries, the
 * platforms' native libraries, `App.deps.json` and `App.exe`. Its libraries are hxc's `--net-lib`s,
 * and `install` copies the lot beside the app, keeping the .dll and runtimeconfig hxc wrote.
 */
class IlLibraries {
	/** What the externs name, beside any package the app adds. **/
	static final LIBRARIES = [
		"Avalonia.Base", "Avalonia.Controls", "Avalonia.Skia", "Avalonia.Desktop", "Avalonia.Themes.Simple", "SkiaSharp", "Svg.Skia", "Svg.Custom",
		"ShimSkiaSharp"
	];

	static inline var COMPLETE = ".complete";

	static var appName:String;
	static var appHeadless:Bool;
	static var output:String;
	static var added:Map<String, Bool> = [];

	public static function prepare(name:String, headless:Bool):Void {
		appName = name;
		appHeadless = headless;
		var packages = Build.packageItems(Build.basePackages(headless));
		var key = name + "-" + (headless ? "headless-" : "") + haxe.crypto.Md5.encode(packages.join("\n"));
		var dir = Path.join([Build.libraryRoot(), ".cache", "il", key]);
		output = Path.join([dir, "out"]);
		if (!FileSystem.exists(Path.join([output, COMPLETE]))) {
			build(dir, name, headless, packages);
		}
		var libraries = LIBRARIES.copy();
		if (headless) {
			libraries.push("Avalonia.Headless");
		}
		for (app in Build.appPackages.keys()) {
			if (FileSystem.exists(Path.join([output, app + ".dll"]))) {
				libraries.push(app);
			}
		}
		for (library in libraries) {
			if (!added.exists(library)) {
				added.set(library, true);
				Compiler.addNativeLib(Path.join([output, library + ".dll"]));
			}
		}
	}

	/** `prepare` again, if it has run, for a package that came after it. **/
	public static function packageAdded():Void {
		if (appName != null) {
			prepare(appName, appHeadless);
		}
	}

	static function build(dir:String, name:String, headless:Bool, packages:Array<String>):Void {
		FileSystem.createDirectory(dir);
		var template = File.getContent(Path.join([Build.libraryRoot(), "templates", "IlLibraries.csproj"]));
		var csproj = Path.join([dir, "App.csproj"]);
		File.saveContent(csproj, template
			.split("::OUTPUT_TYPE::").join(Build.outputType(headless))
			.split("::NAME::").join(name)
			.split("::PACKAGES::").join(packages.join("\n")));
		File.saveContent(Path.join([dir, "Main.cs"]), "static class Program { static void Main() { } }\n");
		var said = "";
		var code = -1;
		try {
			var dotnet = new Process("dotnet", ["build", csproj, "-nologo", "-v", "q"]);
			said = dotnet.stdout.readAll().toString() + dotnet.stderr.readAll().toString();
			code = dotnet.exitCode();
			dotnet.close();
		} catch (e:Dynamic) {
			said = Std.string(e);
		}
		if (code != 0) {
			Context.fatalError('haxeui-cs: fetching Avalonia and the other libraries for $name failed (dotnet build $csproj):\n$said', Context.currentPos());
		}
		File.saveContent(Path.join([output, COMPLETE]), "");
	}

	public static function install(outDir:String):Void {
		copy(output, outDir, [COMPLETE => true, '$appName.dll' => true, '$appName.pdb' => true, '$appName.runtimeconfig.json' => true]);
	}

	static function copy(from:String, to:String, leave:Map<String, Bool>):Void {
		FileSystem.createDirectory(to);
		for (name in FileSystem.readDirectory(from)) {
			if (leave.exists(name)) {
				continue;
			}
			var source = Path.join([from, name]);
			var target = Path.join([to, name]);
			if (FileSystem.isDirectory(source)) {
				copy(source, target, []);
			} else if (!FileSystem.exists(target) || FileSystem.stat(target).size != FileSystem.stat(source).size) {
				File.copy(source, target);
			}
		}
	}
}
#end
