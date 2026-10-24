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
 */
class Build {
	static inline var AVALONIA_VERSION = "12.1.4";
	static inline var SVG_SKIA_VERSION = "5.1.1";

	public static function configure():Void {
		Context.onAfterGenerate(afterGenerate);
	}

	static function afterGenerate():Void {
		var out = Path.normalize(FileSystem.absolutePath(Compiler.getOutput()));
		var name = mainClassName();
		var headless = Context.defined("haxeui_cs_headless");

		var csproj = Path.join([out, name + ".csproj"]);
		File.saveContent(csproj, buildProject(name, headless, resourceItems(out)));

		if (Context.defined("haxeui_cs_no_dotnet")) {
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

	static function buildProject(name:String, headless:Bool, resources:Array<String>):String {
		var nativeDir = Path.join([libraryRoot(), "native"]);
		var native = [];
		for (file in FileSystem.readDirectory(nativeDir)) {
			if (!StringTools.endsWith(file, ".cs")) continue;
			if (file == "TestDriver.cs" && !headless) continue;
			native.push('    <Compile Include="${Path.join([nativeDir, file])}" />');
		}

		// Svg.Skia draws SVG images: 5.1.1 is the newest on Avalonia's own SkiaSharp (3.119) and
		// HarfBuzzSharp (8.3.1.3); later ones need SkiaSharp 4 and would pull it out from under Avalonia.
		var versions = ["Svg.Skia" => SVG_SKIA_VERSION];
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
			.split("::PACKAGES::").join([for (p in packages) '    <PackageReference Include="$p" Version="${versions.exists(p) ? versions.get(p) : AVALONIA_VERSION}" />'].join("\n"));
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
