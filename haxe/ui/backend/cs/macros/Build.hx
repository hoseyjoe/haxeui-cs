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
 * `-D haxeui_cs_run`       run the program after building it
 * `-D haxeui_cs_no_dotnet` stop after writing the .csproj
 * `-D haxeui_cs_publish=<rid>` instead of a debug build, publish a release build for that
 *                          runtime (win-x64, linux-x64, osx-arm64...): one self-contained
 *                          file, native libraries inside, no .pdb, in `<cs-out>/publish/<rid>/`
 * `-D haxeui_cs_android`   an Android app instead (`templates/AndroidApp.csproj` and
 *                          `templates/android/MainActivity.cs`): a debug APK, and with
 *                          `haxeui_cs_run` installed and launched on the device adb sees
 *                          (ANDROID_SERIAL picks one). Needs `-D haxeui_cs_android_id=<id>` and
 *                          `-D haxeui_cs_android_label=<label>`; `-D haxeui_cs_android_abi=`
 *                          `arm64-v8a` (a phone, the default) or `x86_64` (the emulator)
 *
 * `--macro haxe.ui.backend.cs.macros.Build.addPackage("Name", "1.2.3")` adds a NuGet package
 * the app needs beside haxeui-cs's own (a SQLite provider, say), and
 * `--macro haxe.ui.backend.cs.macros.Build.addNative("path")` the app's own C# (a `.cs` file, or
 * every `.cs` in a folder), compiled with haxeui-cs's `native/*.cs`.
 */
class Build {
	static inline var AVALONIA_VERSION = "12.1.4";
	static inline var SVG_SKIA_VERSION = "5.1.1";

	static var appPackages:Map<String, String> = [];
	static var appNatives:Array<String> = [];

	public static function configure():Void {
		Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.OrdinalStringTools.build())", "StringTools");
		Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.NativeUncompress.build())", "haxe.zip.Uncompress");
		if (Context.defined("haxeui_cs_android")) TouchPatches.init();
		Context.onGenerate(GenericInterfaceCast.gather);
		Context.onAfterGenerate(afterGenerate);
	}

	/** A NuGet package the app's own code needs, written into the generated .csproj. **/
	public static function addPackage(name:String, version:String):Void {
		appPackages.set(name, version);
	}

	/** The app's own C#: a `.cs` file, or every `.cs` in a folder, relative to where Haxe runs. **/
	public static function addNative(path:String):Void {
		var full = Path.normalize(FileSystem.absolutePath(path));
		if (!FileSystem.exists(full)) {
			Context.fatalError('haxeui-cs: addNative: $path does not exist', Context.currentPos());
		}
		if (appNatives.indexOf(full) < 0) appNatives.push(full);
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
		if (Context.defined("haxeui_cs_publish")) {
			Context.fatalError("haxeui-cs: -D haxeui_cs_publish is not supported with -D haxeui_cs_android yet", Context.currentPos());
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
		GenericInterfaceCast.fix(Path.join([out, "src"]));

		var main = Compiler.getConfiguration().mainClass;
		var activity = File.getContent(Path.join([libraryRoot(), "templates", "android", "MainActivity.cs"]))
			.split("::LABEL::").join(csString(label))
			.split("::MAIN::").join(main.pack.concat([main.name]).join("."));
		FileSystem.createDirectory(Path.join([out, "android"]));
		File.saveContent(Path.join([out, "android", "MainActivity.cs"]), activity);

		var csproj = Path.join([out, name + ".csproj"]);
		var packages = ["Avalonia", "Avalonia.Android", "Avalonia.Themes.Simple", "Svg.Skia"];
		File.saveContent(csproj, File.getContent(Path.join([libraryRoot(), "templates", "AndroidApp.csproj"]))
			.split("::NAME::").join(name)
			.split("::APP_ID::").join(StringTools.htmlEscape(id))
			.split("::LABEL::").join(StringTools.htmlEscape(label))
			.split("::RID::").join(rid)
			.split("::NATIVE_DIR::").join(nativeItems(false).join("\n"))
			.split("::RESOURCES::").join(resourceItems(out).join("\n"))
			.split("::PACKAGES::").join(packageItems(packages).join("\n")));

		if (Context.defined("haxeui_cs_no_dotnet")) {
			return;
		}
		var code = Sys.command("dotnet", ["build", csproj, "-c", "Debug", "-nologo", "-v", "q"]);
		if (code != 0) {
			Sys.exit(code);
		}
		if (Context.defined("haxeui_cs_run")) {
			var apk = Path.join([out, "bin", "Debug", "net10.0-android", rid, id + "-Signed.apk"]);
			// Not incremental: adb's incremental install has hung an emulator part way.
			code = Sys.command("adb", ["install", "--no-incremental", "-r", apk]);
			if (code != 0) {
				Sys.exit(code);
			}
			code = Sys.command("adb", ["shell", "monkey", "-p", id, "-c", "android.intent.category.LAUNCHER", "1"]);
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
	 * libraries (Skia, HarfBuzz...) inside, no .pdb beside it. Not trimmed: Haxe's output and
	 * HaxeUI find classes by name at run time, which trimming would cut away.
	 */
	static function publish(out:String, name:String, csproj:String, rid:String):Void {
		// a bare `-D haxeui_cs_publish` has the value "1"
		if (rid == null || rid == "" || rid == "1") {
			Context.fatalError("haxeui-cs: -D haxeui_cs_publish needs a runtime id, e.g. -D haxeui_cs_publish=win-x64", Context.currentPos());
		}
		var dir = Path.join([out, "publish", rid]);
		var code = Sys.command("dotnet", [
			"publish", csproj, "-c", "Release", "-r", rid, "--self-contained",
			"-p:PublishSingleFile=true", "-p:IncludeNativeLibrariesForSelfExtract=true", "-p:DebugType=none",
			"-o", dir, "-nologo", "-v", "q"
		]);
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

	/** haxeui-cs's `native/*.cs` (TestDriver only headless) and the app's own, as Compile items. **/
	static function nativeItems(headless:Bool):Array<String> {
		var nativeDir = Path.join([libraryRoot(), "native"]);
		var native = [];
		for (file in FileSystem.readDirectory(nativeDir)) {
			if (!StringTools.endsWith(file, ".cs")) continue;
			if (file == "TestDriver.cs" && !headless) continue;
			native.push('    <Compile Include="${Path.join([nativeDir, file])}" />');
		}
		for (path in appNatives) {
			native.push('    <Compile Include="${FileSystem.isDirectory(path) ? Path.join([path, "*.cs"]) : path}" />');
		}
		return native;
	}

	/** haxeui-cs's packages and then the app's, as PackageReference items. **/
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

	static function buildProject(name:String, headless:Bool, resources:Array<String>):String {
		var native = nativeItems(headless);
		var packages = ["Avalonia", "Avalonia.Desktop", "Avalonia.Themes.Simple", "Svg.Skia"];
		if (headless) {
			packages.push("Avalonia.Headless");
		}

		var outputType = (headless || Context.defined("debug")) ? "Exe" : "WinExe";
		var template = File.getContent(Path.join([libraryRoot(), "templates", "App.csproj"]));
		return template
			.split("::OUTPUT_TYPE::").join(outputType)
			.split("::NAME::").join(name)
			.split("::DEFINES::").join(headless ? ";HAXEUI_CS_HEADLESS" : "")
			.split("::NATIVE_DIR::").join(native.join("\n"))
			.split("::RESOURCES::").join(resources.join("\n"))
			.split("::PACKAGES::").join(packageItems(packages).join("\n"));
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
	static function libraryRoot():String {
		var self = Context.resolvePath("haxe/ui/backend/cs/macros/Build.hx");
		return Path.normalize(Path.join([Path.directory(FileSystem.absolutePath(self)), "..", "..", "..", "..", ".."]));
	}
}
#end
