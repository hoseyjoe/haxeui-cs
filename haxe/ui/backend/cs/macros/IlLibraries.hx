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
 *
 * The app's own C# (`Build.addNative`) is `App.Native.dll` there, a project the empty app references,
 * so hxc builds against it and the host finds it through `App.deps.json`. A `--net-lib` the app gives
 * hxc itself is not in that file, and the host would not load it. An edit to that C# rebuilds the
 * project where it is: `.complete` holds what the last build compiled.
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
		var natives = Build.nativeItems();
		var key = name + "-" + (headless ? "headless-" : "") + haxe.crypto.Md5.encode(Build.outputType(headless) + "\n" + packages.concat(natives).join("\n"));
		var dir = Path.join([Build.libraryRoot(), ".cache", "il", key]);
		output = Path.join([dir, "out"]);
		var complete = Path.join([output, COMPLETE]);
		var compiled = nativeSources();
		if (!FileSystem.exists(complete) || File.getContent(complete) != compiled) {
			build(dir, name, headless, packages, natives);
			File.saveContent(complete, compiled);
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
		if (natives.length > 0) {
			libraries.push('$name.Native');
		}
		for (library in libraries) {
			if (!added.exists(library)) {
				added.set(library, true);
				Compiler.addNativeLib(Path.join([output, library + ".dll"]));
			}
		}
	}

	/** `prepare` again, if it has run, for a package or C# that came after it. **/
	public static function appAdded():Void {
		if (appName != null) {
			prepare(appName, appHeadless);
		}
	}

	/** Each of the app's own `.cs` files and its digest, to tell when the C# has changed. **/
	static function nativeSources():String {
		var files = [];
		for (path in Build.appNatives) {
			if (FileSystem.isDirectory(path)) {
				for (entry in FileSystem.readDirectory(path)) {
					if (Path.extension(entry).toLowerCase() == "cs") {
						files.push(Path.join([path, entry]));
					}
				}
			} else {
				files.push(path);
			}
		}
		files.sort(Reflect.compare);
		return [for (file in files) file + " " + haxe.crypto.Md5.make(File.getBytes(file)).toHex()].join("\n");
	}

	static function build(dir:String, name:String, headless:Bool, packages:Array<String>, natives:Array<String>):Void {
		FileSystem.createDirectory(dir);
		var template = File.getContent(Path.join([Build.libraryRoot(), "templates", "IlLibraries.csproj"]));
		var csproj = Path.join([dir, "App.csproj"]);
		File.saveContent(csproj, template
			.split("::OUTPUT_TYPE::").join(Build.outputType(headless))
			.split("::NAME::").join(name)
			.split("::NATIVE_PROJECT::").join(natives.length > 0 ? '    <ProjectReference Include="native/Native.csproj" />' : "")
			.split("::PACKAGES::").join(packages.join("\n")));
		File.saveContent(Path.join([dir, "Main.cs"]), "static class Program { static void Main() { } }\n");
		if (natives.length > 0) {
			FileSystem.createDirectory(Path.join([dir, "native"]));
			File.saveContent(Path.join([dir, "native", "Native.csproj"]), File.getContent(Path.join([Build.libraryRoot(), "templates", "IlNative.csproj"]))
				.split("::NAME::").join(name)
				.split("::NATIVE_DIR::").join(natives.join("\n"))
				.split("::PACKAGES::").join(packages.join("\n")));
		}
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
			var what = natives.length > 0 ? "fetching Avalonia and the other libraries, or compiling the app's own C#," : "fetching Avalonia and the other libraries";
			Context.fatalError('haxeui-cs: $what for $name failed (dotnet build $csproj):\n$said', Context.currentPos());
		}
	}

	public static function install(outDir:String):Void {
		copy(output, outDir, [COMPLETE => true, '$appName.dll' => true, '$appName.pdb' => true, '$appName.runtimeconfig.json' => true]);
		// The same size whichever output type it was built for, and after an edit that doesn't change
		// the size the sections round to, so copy never sees the change.
		for (file in ['$appName.exe', '$appName.Native.dll', '$appName.Native.pdb']) {
			var source = Path.join([output, file]);
			if (FileSystem.exists(source)) {
				File.copy(source, Path.join([outDir, file]));
			}
		}
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
