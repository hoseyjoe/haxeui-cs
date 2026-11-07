package haxe.ui.backend.cs.macros;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

/**
 * Turns Haxe's generated C# into a running .NET app.
 *
 * Haxe only writes `.cs` sources (`-D no-compilation`); after it has, this
 * writes `<cs-out>/<Main>.csproj` from `templates/App.csproj`, runs
 * `dotnet build`, and with `-D haxeui_cs_run` runs the result. Any non-zero
 * exit code ends the Haxe compile with that code.
 *
 * `-D haxeui_cs_headless`  headless Avalonia host + Avalonia.Headless (tests)
 * `-D haxeui_cs_drive`     AppDriver: raw input and window capture for a driver (heaps-drive),
 *                          handed straight to the window, never through the OS
 * `-D haxeui_cs_run`       run the program after building it
 * `-D haxeui_cs_no_dotnet` stop after writing the .csproj
 * `-D haxeui_cs_publish=<rid>` instead of a debug build, publish a release build for that
 *                          runtime (win-x64, linux-x64, osx-arm64...): one self-contained
 *                          file, native libraries inside, no .pdb, in `<cs-out>/publish/<rid>/`
 * `-D haxeui_cs_trim`      with `haxeui_cs_publish`: trim the libraries that declare themselves
 *                          trimmable (.NET's own, Avalonia's); the app's own code is kept whole
 * `-D haxeui_cs_compress`  with `haxeui_cs_publish`: compress the file (smaller, slower to start)
 * `-D haxeui_cs_android`   an Android app instead (`templates/AndroidApp.csproj` and
 *                          `templates/android/MainActivity.cs`): a debug APK (a Release one,
 *                          partly trimmed, with `haxeui_cs_publish`), and with
 *                          `haxeui_cs_run` installed and launched on the device adb sees
 *                          (ANDROID_SERIAL picks one). Needs `-D haxeui_cs_android_id=<id>` and
 *                          `-D haxeui_cs_android_label=<label>`; `-D haxeui_cs_android_abi=`
 *                          `arm64-v8a` (a phone, the default) or `x86_64` (the emulator)
 *
 * `--macro haxe.ui.backend.cs.macros.Build.addPackage("Name", "1.2.3")` adds a NuGet package
 * the app needs beside haxeui-cs's own (a SQLite provider, say), and
 * `--macro haxe.ui.backend.cs.macros.Build.addNative("path")` the app's own C# (a `.cs` file, or
 * every `.cs` in a folder), compiled with the generated C#.
 *
 * With hxc's `--dotnet` none of this runs: see configureIl. Nor with `--no-output`, a type check:
 * Haxe calls onAfterGenerate without having generated, so `dotnet build` would compile the C# of
 * the last real build against today's sources.
 */
class Build {
	static inline var AVALONIA_VERSION = "12.1.4";
	static inline var SVG_SKIA_VERSION = "5.1.1";

	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static var appPackages:Map<String, String> = [];
	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static var appNatives:Array<String> = [];

	public static function configure():Void {
		if (Context.defined("haxeui_cs_android") && Context.defined("haxeui_cs_headless")) {
			Context.fatalError("haxeui-cs: -D haxeui_cs_android and -D haxeui_cs_headless cannot be used together", Context.currentPos());
		}
		// The define alone would have hxc write IL and then the C# build run `dotnet build` on whatever C# was there.
		if (Context.defined("dotnet") && !isIl()) {
			Context.fatalError("haxeui-cs: -D dotnet needs --dotnet <dir> in place of --cs <dir>", Context.currentPos());
		}
		Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.OrdinalStringTools.build())", "StringTools");
		Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.NativeUncompress.build())", "haxe.zip.Uncompress");
		Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.NativeCompress.build())", "haxe.zip.Compress");
		// A class only C# calls must still be generated, as HostApplication is for MainActivity.cs.
		Compiler.include("haxe.ui.backend.cs.native");
		Compiler.keep("haxe.ui.backend.cs.native");
		if (Context.defined("haxeui_cs_android")) TouchPatches.init();
		if (isIl()) {
			configureIl();
			return;
		}
		if (Compiler.getConfiguration().args.indexOf("--no-output") >= 0) {
			return;
		}
		Context.onGenerate(GenericInterfaceCast.gather);
		Context.onAfterGenerate(afterGenerate);
	}

	/** Whether the hxml asks hxc for IL. `--dotnet` sets the `dotnet` define too, but only the flag counts. **/
	static function isIl():Bool {
		return Compiler.getConfiguration().args.indexOf("--dotnet") >= 0;
	}

	/**
	 * hxc's `--dotnet` writes the app's .dll itself, with no C# source, .csproj or `dotnet build`, so
	 * nothing here runs after generating. `main` is marked with `[STAThread]` (see markEntryPointSta)
	 * and hxc carries that to the entry point it writes. IlLibraries fetches Avalonia and puts it
	 * beside the app, with the app's own C# as a library. The app is `<Main>.dll` unless `-D dll-name`
	 * says otherwise, as a C# build's is.
	 *
	 * With `haxeui_cs_android` the .dll is the app's code and no more: see ilAndroid.
	 */
	static function configureIl():Void {
		var android = Context.defined("haxeui_cs_android");
		// On Android both are the APK's: publish its Release build, run its install.
		if (!android) {
			for (define in ["haxeui_cs_publish", "haxeui_cs_run"]) {
				if (Context.defined(define)) {
					Context.fatalError('haxeui-cs: -D $define needs the C# build, not --dotnet', Context.currentPos());
				}
			}
		}
		// Before anything is fetched or compiled, as the C# build checks them before its dotnet build.
		var target = android ? androidTarget() : null;
		var name = mainClassName();
		var main = Compiler.getConfiguration().mainClass;
		// Android's main runs from MainActivity, on Avalonia's thread: there is no entry point to mark.
		if (!android) Compiler.addMetadata("@:meta(System.STAThread())", main.pack.concat([name]).join("."), "main", true);
		Compiler.define("unsafe");
		var dll = Context.definedValue("dll-name");
		if (dll == null) {
			dll = name;
			Compiler.define("dll-name", dll);
		}
		IlLibraries.prepare(dll, Context.defined("haxeui_cs_headless"));
		if (Compiler.getConfiguration().args.indexOf("--no-output") < 0) {
			var out = Path.normalize(FileSystem.absolutePath(Compiler.getOutput()));
			Context.onAfterGenerate(() -> android ? ilAndroid(out, dll, target) : IlLibraries.install(out));
		}
	}

	/** A NuGet package the app's own code needs, written into the generated .csproj. **/
	public static function addPackage(name:String, version:String):Void {
		appPackages.set(name, version);
		// `-lib haxeui-cs` usually comes first, so hxc's libraries are already prepared.
		if (isIl()) IlLibraries.appAdded();
	}

	/** The app's own C#: a `.cs` file, or every `.cs` in a folder, relative to where Haxe runs. **/
	public static function addNative(path:String):Void {
		var full = Path.normalize(FileSystem.absolutePath(path));
		if (!FileSystem.exists(full)) {
			Context.fatalError('haxeui-cs: addNative: $path does not exist', Context.currentPos());
		}
		if (appNatives.indexOf(full) < 0) appNatives.push(full);
		if (isIl()) IlLibraries.appAdded();
	}

	static function afterGenerate():Void {
		var out = Path.normalize(FileSystem.absolutePath(Compiler.getOutput()));
		var name = mainClassName();
		var headless = Context.defined("haxeui_cs_headless");
		if (Context.defined("haxeui_cs_android")) {
			android(out, name);
			return;
		}
		GenericInterfaceCast.fix(Path.join([out, "src"]));
		markEntryPointSta(Path.join([out, "src"]));

		var csproj = Path.join([out, name + ".csproj"]);
		File.saveContent(csproj, buildProject(name, headless, resourceItems(out)));

		if (Context.defined("haxeui_cs_no_dotnet")) {
			return;
		}
		if (Context.defined("haxeui_cs_publish")) {
			publish(out, name, csproj, Context.definedValue("haxeui_cs_publish"));
			return;
		}
		var code = Sys.command("dotnet", ["build", csproj, "-nologo", "-v", "q"]);
		if (code != 0) {
			Sys.exit(code);
		}
		if (Context.defined("haxeui_cs_run")) {
			var dll = Path.join([out, "bin", "Debug", "net10.0", name + ".dll"]);
			code = Sys.command("dotnet", [dll]);
			if (code != 0) {
				Sys.exit(code);
			}
		}
	}

	/**
	 * The Android app: the project and its MainActivity, a debug APK, and with `haxeui_cs_run` that
	 * APK installed and launched. Haxe's `main` is not the process's entry point there: Android
	 * starts MainActivity, and the host calls `main` from it (Host.Entry), so there is no
	 * `[STAThread]` to add either.
	 */
	static function android(out:String, name:String):Void {
		var target = androidTarget();
		GenericInterfaceCast.fix(Path.join([out, "src"]));
		writeActivity(Path.join([out, "android", "MainActivity.cs"]));
		var csproj = Path.join([out, name + ".csproj"]);
		var sources = ['    <Compile Include="src/**/*.cs" />', '    <Compile Include="android/*.cs" />'];
		File.saveContent(csproj, androidProject(name, target, sources, nativeItems(), resourceItems(out)));
		buildAndroid(csproj, out, target);
	}

	/**
	 * The Android app under hxc's `--dotnet`. hxc has written `<dll>.dll`, the app's whole program with
	 * its resources inside; Android's packaging (the manifest, MainActivity's Java side, the APK) has
	 * only a `net10.0-android` project to give it, so the app is a library of a project of its own,
	 * `<out>/android/<dll>.Android.csproj`, which holds nothing but MainActivity. That calls Haxe's
	 * `cs.Boot.init` and `main` in the .dll as the C# build's calls them in its sources, and not the
	 * .dll's entry point: after `main`, that runs the main thread's events until there are none,
	 * which on Avalonia's thread is never. The app's own C# (`addNative`) is the `<dll>.Native.dll`
	 * IlLibraries built for Android, with `HAXEUI_CS_ANDROID`; hxc compiled against IlLibraries'
	 * Android libraries, the same ones this project's packages bring.
	 */
	static function ilAndroid(out:String, dll:String, target:AndroidTarget):Void {
		var dir = Path.join([out, "android"]);
		writeActivity(Path.join([dir, "MainActivity.cs"]));
		var references = [Path.join([out, dll + ".dll"])];
		var native = IlLibraries.nativeLibrary();
		if (native != null) references.push(native);
		var sources = ['    <Compile Include="MainActivity.cs" />'];
		for (path in references) {
			sources.push('    <Reference Include="${StringTools.htmlEscape(path, true)}" />');
		}
		var csproj = Path.join([dir, dll + ".Android.csproj"]);
		File.saveContent(csproj, androidProject(dll + ".Android", target, sources, [], []));
		buildAndroid(csproj, dir, target);
	}

	/**
	 * The application id, label, runtime and configuration the defines name, or a compile error saying
	 * which is wrong. `haxeui_cs_publish` is the Release build (the project's Release group says what
	 * that is); it takes no runtime here, since `haxeui_cs_android_abi` names the one an APK is for.
	 */
	static function androidTarget():AndroidTarget {
		var publish = Context.definedValue("haxeui_cs_publish");
		if (publish != null && publish != "" && publish != "1") {
			Context.fatalError('haxeui-cs: -D haxeui_cs_publish=$publish: with -D haxeui_cs_android it takes no runtime; -D haxeui_cs_android_abi picks the ABI',
				Context.currentPos());
		}
		var id = definedText("haxeui_cs_android_id");
		if (id == null) {
			Context.fatalError("haxeui-cs: -D haxeui_cs_android needs -D haxeui_cs_android_id=<application id>", Context.currentPos());
		}
		var label = definedText("haxeui_cs_android_label");
		if (label == null) {
			Context.fatalError("haxeui-cs: -D haxeui_cs_android needs -D haxeui_cs_android_label=<label>", Context.currentPos());
		}
		var abi = definedText("haxeui_cs_android_abi");
		var rid = switch (abi) {
			case null | "arm64-v8a": "android-arm64";
			case "x86_64": "android-x64";
			case _: Context.fatalError('haxeui-cs: -D haxeui_cs_android_abi=$abi: arm64-v8a or x86_64', Context.currentPos());
		}
		return {id: id, label: label, rid: rid, configuration: publish != null ? "Release" : "Debug"};
	}

	static function writeActivity(path:String):Void {
		var main = Compiler.getConfiguration().mainClass;
		var activity = File.getContent(Path.join([libraryRoot(), "templates", "android", "MainActivity.cs"]))
			.split("::LABEL::").join(csString(androidTarget().label))
			.split("::MAIN::").join(main.pack.concat([main.name]).join("."));
		FileSystem.createDirectory(Path.directory(path));
		File.saveContent(path, activity);
	}

	static function androidProject(assembly:String, target:AndroidTarget, sources:Array<String>, natives:Array<String>, resources:Array<String>):String {
		return File.getContent(Path.join([libraryRoot(), "templates", "AndroidApp.csproj"]))
			.split("::ASSEMBLY::").join(assembly)
			.split("::APP_ID::").join(StringTools.htmlEscape(target.id))
			.split("::LABEL::").join(StringTools.htmlEscape(target.label))
			.split("::RID::").join(target.rid)
			.split("::SOURCES::").join(sources.join("\n"))
			.split("::NATIVE_DIR::").join(natives.join("\n"))
			.split("::RESOURCES::").join(resources.join("\n"))
			.split("::PACKAGES::").join(packageItems(basePackages(false)).join("\n"));
	}

	/**
	 * `dotnet build` of the Android project in `projectDir` for the target's configuration, then with
	 * `haxeui_cs_run` the install and launch. The APK is `bin/<configuration>/net10.0-android/<rid>/
	 * <id>-Signed.apk` there; a Release one is signed with the SDK's debug key, as a debug one is.
	 */
	static function buildAndroid(csproj:String, projectDir:String, target:AndroidTarget):Void {
		if (Context.defined("haxeui_cs_no_dotnet")) {
			return;
		}
		var code = Sys.command("dotnet", ["build", csproj, "-c", target.configuration, "-nologo", "-v", "q"]);
		if (code != 0) {
			Sys.exit(code);
		}
		var apk = Path.join([projectDir, "bin", target.configuration, "net10.0-android", target.rid, target.id + "-Signed.apk"]);
		if (target.configuration == "Release") {
			Sys.println('haxeui-cs: $apk');
		}
		if (Context.defined("haxeui_cs_run")) {
			// Not incremental: adb's incremental install has hung an emulator part way.
			code = Sys.command("adb", ["install", "--no-incremental", "-r", apk]);
			if (code != 0) {
				Sys.exit(code);
			}
			code = Sys.command("adb", ["shell", "monkey", "-p", target.id, "-c", "android.intent.category.LAUNCHER", "1"]);
			if (code != 0) {
				Sys.exit(code);
			}
		}
	}

	/** A define's value, or null when it is not set (a bare `-D name` has the value "1"). **/
	static function definedText(name:String):Null<String> {
		var value = Context.definedValue(name);
		return value == null || value == "" || value == "1" ? null : value;
	}

	/** Text for a C# string literal. **/
	static function csString(text:String):String {
		return text.split("\\").join("\\\\").split("\"").join("\\\"");
	}

	/**
	 * A release build as one self-contained file for `rid`: the .NET runtime and the native
	 * libraries (Skia, HarfBuzz...) inside, no .pdb beside it. Not trimmed unless asked
	 * (`haxeui_cs_trim`), and then only partly: Haxe's output and HaxeUI find classes by name at
	 * run time, so the app's own assembly, which does not declare itself trimmable, is kept whole.
	 */
	static function publish(out:String, name:String, csproj:String, rid:String):Void {
		// a bare `-D haxeui_cs_publish` has the value "1"
		if (rid == null || rid == "" || rid == "1") {
			Context.fatalError("haxeui-cs: -D haxeui_cs_publish needs a runtime id, e.g. -D haxeui_cs_publish=win-x64", Context.currentPos());
		}
		var dir = Path.join([out, "publish", rid]);
		var args = [
			"publish", csproj, "-c", "Release", "-r", rid, "--self-contained",
			"-p:PublishSingleFile=true", "-p:IncludeNativeLibrariesForSelfExtract=true", "-p:DebugType=none"
		];
		if (Context.defined("haxeui_cs_trim")) {
			// partial: only the assemblies marked IsTrimmable, so not the app's own
			args = args.concat(["-p:PublishTrimmed=true", "-p:TrimMode=partial"]);
		}
		if (Context.defined("haxeui_cs_compress")) {
			args.push("-p:EnableCompressionInSingleFile=true");
		}
		var code = Sys.command("dotnet", args.concat(["-o", dir, "-nologo", "-v", "q"]));
		if (code != 0) {
			Sys.exit(code);
		}
		// DebugType=none drops the app's own symbols; the Skia and HarfBuzz packages ship
		// theirs (100 MB of .pdb) beside the native libraries, so those go here.
		for (file in FileSystem.readDirectory(dir)) {
			if (Path.extension(file).toLowerCase() == "pdb") {
				FileSystem.deleteFile(Path.join([dir, file]));
			}
		}
		if (Context.defined("haxeui_cs_run")) {
			// a program published for another OS cannot run here
			var host = switch (Sys.systemName()) {
				case "Windows": "win";
				case "Mac": "osx";
				case _: "linux";
			}
			if (!StringTools.startsWith(rid, host)) {
				Sys.println('haxeui-cs: published for $rid in $dir; not run on this ${Sys.systemName()} machine');
				return;
			}
			code = Sys.command(Path.join([dir, host == "win" ? name + ".exe" : name]), []);
			if (code != 0) {
				Sys.exit(code);
			}
		}
	}

	/** The app's own C#, as Compile items. **/
	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static function nativeItems():Array<String> {
		return [for (path in appNatives) '    <Compile Include="${FileSystem.isDirectory(path) ? Path.join([path, "*.cs"]) : path}" />'];
	}

	/** haxeui-cs's packages and then the app's, as PackageReference items. **/
	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static function packageItems(packages:Array<String>):Array<String> {
		// Svg.Skia draws SVG images: 5.1.1 is the newest on Avalonia's own SkiaSharp (3.119) and
		// HarfBuzzSharp (8.3.1.3); later ones need SkiaSharp 4 and would pull it out from under Avalonia.
		var versions = ["Svg.Skia" => SVG_SKIA_VERSION];
		for (name => version in appPackages) {
			if (packages.indexOf(name) < 0) packages.push(name);
			versions.set(name, version);
		}
		return [for (p in packages) '    <PackageReference Include="$p" Version="${versions.exists(p) ? versions.get(p) : AVALONIA_VERSION}" />'];
	}

	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static function basePackages(headless:Bool):Array<String> {
		if (Context.defined("haxeui_cs_android")) {
			return ["Avalonia", "Avalonia.Android", "Avalonia.Themes.Simple", "Svg.Skia"];
		}
		var packages = ["Avalonia", "Avalonia.Desktop", "Avalonia.Themes.Simple", "Svg.Skia"];
		if (headless) {
			packages.push("Avalonia.Headless");
		}
		return packages;
	}

	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static function outputType(headless:Bool):String {
		return (headless || Context.defined("debug")) ? "Exe" : "WinExe";
	}

	static function buildProject(name:String, headless:Bool, resources:Array<String>):String {
		var template = File.getContent(Path.join([libraryRoot(), "templates", "App.csproj"]));
		return template
			.split("::OUTPUT_TYPE::").join(outputType(headless))
			.split("::NAME::").join(name)
			.split("::NATIVE_DIR::").join(nativeItems().join("\n"))
			.split("::RESOURCES::").join(resources.join("\n"))
			.split("::PACKAGES::").join(packageItems(basePackages(headless)).join("\n"));
	}

	/**
	 * Haxe writes each resource to `src/Resources/<escaped name>`, and a name
	 * with slashes (`haxeui-core/styles/...`) becomes nested folders. haxe.Resource
	 * finds them by manifest name `Resources.<escaped name>` with forward
	 * slashes, so each file is listed with exactly that logical name.
	 */
	static function resourceItems(out:String):Array<String> {
		var items = [];
		function walk(dir:String, relative:String) {
			if (!FileSystem.exists(dir)) return;
			for (entry in FileSystem.readDirectory(dir)) {
				var full = Path.join([dir, entry]);
				var rel = relative == "" ? entry : relative + "/" + entry;
				if (FileSystem.isDirectory(full)) {
					walk(full, rel);
				} else {
					items.push('    <EmbeddedResource Include="src/Resources/$rel" LogicalName="Resources.$rel" />');
				}
			}
		}
		walk(Path.join([out, "src", "Resources"]), "");
		return items;
	}

	/**
	 * `[STAThread]` on the generated `Main`, as every Avalonia app's Program.Main has: Windows' OLE
	 * (the clipboard, drag and drop) works only on a single-threaded apartment, and Haxe's entry
	 * point leaves the main thread multi-threaded. Elsewhere the attribute does nothing.
	 */
	static function markEntryPointSta(src:String):Void {
		var main = Compiler.getConfiguration().mainClass;
		var file = Path.join([src].concat(main.pack).concat([main.name + ".cs"]));
		// `EntryPoint__Main` for a top-level class, the class itself for one in a package
		var entry = ~/^([ \t]*)public static void Main\(\)\s*\{/m;
		var text = FileSystem.exists(file) ? File.getContent(file) : "";
		if (!entry.match(text)) {
			Context.fatalError('haxeui-cs: no entry point in $file to mark [STAThread]', Context.currentPos());
		}
		// already marked: a second afterGenerate, or another build over the same output
		if (StringTools.endsWith(StringTools.rtrim(entry.matchedLeft()), "[System.STAThread]")) {
			return;
		}
		var indent = entry.matched(1);
		File.saveContent(file, entry.matchedLeft() + indent + "[System.STAThread]\n" + entry.matched(0) + entry.matchedRight());
	}

	static function mainClassName():String {
		var config = Compiler.getConfiguration();
		if (config == null || config.mainClass == null) {
			Context.fatalError("haxeui-cs: the app needs a -main class", Context.currentPos());
		}
		return config.mainClass.name;
	}

	/** The haxeui-cs checkout, found through this file's own classpath entry. **/
	@:allow(haxe.ui.backend.cs.macros.IlLibraries)
	static function libraryRoot():String {
		var self = Context.resolvePath("haxe/ui/backend/cs/macros/Build.hx");
		return Path.normalize(Path.join([Path.directory(FileSystem.absolutePath(self)), "..", "..", "..", "..", ".."]));
	}
}

private typedef AndroidTarget = {id:String, label:String, rid:String, configuration:String};
#end
