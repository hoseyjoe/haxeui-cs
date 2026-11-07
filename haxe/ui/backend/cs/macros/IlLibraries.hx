package haxe.ui.backend.cs.macros;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

/**
 * Avalonia for hxc's `--dotnet`, which writes the app's .dll itself and has no `dotnet build` to
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

	/**
	 * On Android: Avalonia's Android builds of the same libraries, and the platform's own `Mono.Android`,
	 * which the backend's Android code names (Host.RenderScaling's display density). The app's .dll is
	 * then a library of the Android project Build.ilAndroid writes, which brings all of them itself.
	 */
	static final ANDROID_LIBRARIES = [
		"Avalonia.Base", "Avalonia.Controls", "Avalonia.Skia", "Avalonia.Themes.Simple", "SkiaSharp", "Svg.Skia", "Svg.Custom", "ShimSkiaSharp",
		"Mono.Android", "Java.Interop"
	];

	/**
	 * A library project for Android, as an empty app would make an APK: what it gives hxc is the
	 * packages' Android assemblies (copied to `out/` as an app's would be) and the framework's
	 * `Mono.Android` and `Java.Interop`, which no build copies anywhere, so a target copies them.
	 */
	static inline var ANDROID_PROPERTIES = "    <SupportedOSPlatformVersion>26</SupportedOSPlatformVersion>\n"
		+ "    <CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>";

	static inline var ANDROID_TARGETS = "  <Target Name=\"HaxeUICsPlatformLibraries\" AfterTargets=\"Build\">\n"
		+ "    <Copy SourceFiles=\"@(ReferencePath)\" DestinationFolder=\"$(OutDir)\" SkipUnchangedFiles=\"true\"\n"
		+ "      Condition=\"'%(Filename)' == 'Mono.Android' Or '%(Filename)' == 'Java.Interop'\" />\n"
		+ "  </Target>";

	static inline var TFM = "net10.0";
	static inline var ANDROID_TFM = "net10.0-android";

	static function android():Bool {
		return Context.defined("haxeui_cs_android");
	}

	static function outputType(headless:Bool):String {
		return android() ? "Library" : Build.outputType(headless);
	}

	public static function prepare(name:String, headless:Bool):Void {
		appName = name;
		appHeadless = headless;
		var packages = Build.packageItems(Build.basePackages(headless));
		var natives = Build.nativeItems();
		var key = name + "-" + (headless ? "headless-" : "") + (android() ? "android-" : "")
			+ haxe.crypto.Md5.encode(outputType(headless) + "\n" + packages.concat(natives).join("\n"));
		var dir = Path.join([Build.libraryRoot(), ".cache", "il", key]);
		output = Path.join([dir, "out"]);
		var complete = Path.join([output, COMPLETE]);
		var compiled = nativeSources();
		if (!FileSystem.exists(complete) || File.getContent(complete) != compiled) {
			build(dir, name, headless, packages, natives);
			File.saveContent(complete, compiled);
		}
		var libraries = (android() ? ANDROID_LIBRARIES : LIBRARIES).copy();
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
		var tfm = android() ? ANDROID_TFM : TFM;
		File.saveContent(csproj, template
			.split("::OUTPUT_TYPE::").join(outputType(headless))
			.split("::TFM::").join(tfm)
			.split("::NAME::").join(name)
			.split("::PROPERTIES::").join(android() ? ANDROID_PROPERTIES : "")
			.split("::TARGETS::").join(android() ? ANDROID_TARGETS : "")
			.split("::NATIVE_PROJECT::").join(natives.length > 0 ? '    <ProjectReference Include="native/Native.csproj" />' : "")
			.split("::PACKAGES::").join(packages.join("\n")));
		File.saveContent(Path.join([dir, "Main.cs"]), "static class Program { static void Main() { } }\n");
		if (natives.length > 0) {
			FileSystem.createDirectory(Path.join([dir, "native"]));
			// The app's C# sees HAXEUI_CS_ANDROID, as the C# build's Android project defines it.
			var properties = android() ? "    <SupportedOSPlatformVersion>26</SupportedOSPlatformVersion>\n"
				+ "    <DefineConstants>$(DefineConstants);HAXEUI_CS_ANDROID</DefineConstants>" : "";
			File.saveContent(Path.join([dir, "native", "Native.csproj"]), File.getContent(Path.join([Build.libraryRoot(), "templates", "IlNative.csproj"]))
				.split("::TFM::").join(tfm)
				.split("::NAME::").join(name)
				.split("::PROPERTIES::").join(properties)
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

	/** The app's own C# as `<name>.Native.dll` in the cache, or null when it has none. **/
	public static function nativeLibrary():Null<String> {
		var path = Path.join([output, '$appName.Native.dll']);
		return Build.appNatives.length > 0 && FileSystem.exists(path) ? path : null;
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
