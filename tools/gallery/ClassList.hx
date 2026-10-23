#if macro
import haxe.io.Path;
import haxe.macro.Context;
import sys.FileSystem;
#end

/**
 * The gallery's list of classes, read from core's source at compile time so it
 * follows whatever haxeui-core checkout the build uses: one entry per module
 * under haxe/ui/components and haxe/ui/containers.
 */
class ClassList {
	public static macro function all():haxe.macro.Expr {
		var names = [];
		for (pack in ["haxe.ui.components", "haxe.ui.containers"]) {
			var anchor = Context.resolvePath(pack.split(".").join("/") + (pack == "haxe.ui.components" ? "/Button.hx" : "/Box.hx"));
			walk(Path.directory(anchor), pack, names);
		}
		names.sort(Reflect.compare);
		return macro $v{names};
	}

	#if macro
	static function walk(dir:String, pack:String, into:Array<String>) {
		for (entry in FileSystem.readDirectory(dir)) {
			var full = Path.join([dir, entry]);
			if (FileSystem.isDirectory(full)) {
				walk(full, pack + "." + entry, into);
			} else if (Path.extension(entry) == "hx") {
				into.push(pack + "." + Path.withoutExtension(entry));
			}
		}
	}
	#end
}
