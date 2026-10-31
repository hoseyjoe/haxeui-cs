package haxe.ui.backend.cs.macros;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Type;
import sys.FileSystem;
import sys.io.File;

/**
 * A generic class's cast to a generic interface it implements, as it should be.
 *
 * Haxe 4.3's C# output casts between instances of one generic class (`Foo<bool>`
 * to `Foo<object>`) with a generated `pack_Foo_cast<T_c>()`, which copies the
 * object into the other instance. For each generic interface the class
 * implements it writes a forwarder, but passes the class's own parameters
 * where the forwarder's belong:
 *
 *     public virtual object pack_Iface_cast<T_c>() {
 *         return this.pack_Foo_cast<T>();     // should be <T_c>
 *     }
 *
 * so the cast hands back `this` unchanged, and the cast after it throws
 * (`Foo<bool>` is not an `Iface<object>`). thenshim's promises hit it as soon as
 * a `then` handler returns a `Promise<Bool>`.
 *
 * Only a class that implements the interface with its own parameters, in order
 * (`Foo<T> implements Iface<T>`), is put right: there the forwarder's
 * parameters are the class's, renamed. Build.configure gathers those pairs
 * as Haxe hands over its types, and Build fixes the written `.cs` after.
 */
class GenericInterfaceCast {
	/** Each class whose forwarder is put right: the two cast methods' names and the class's parameters. **/
	static var pairs:Array<{iface:String, cls:String, params:Array<String>}> = [];

	public static function gather(types:Array<Type>):Void {
		pairs = [];
		for (t in types) {
			switch (t) {
				case TInst(_.get() => c, _) if (!c.isInterface && !c.isExtern && c.params.length > 0):
					for (i in c.interfaces) {
						if (sameParams(i.params, c.params)) {
							pairs.push({iface: castName(i.t.get()), cls: castName(c), params: [for (p in c.params) p.name]});
						}
					}
				case _:
			}
		}
	}

	/** Puts right every gathered forwarder in the `.cs` under `dir`. **/
	public static function fix(dir:String):Void {
		// no .cs written: hxc's --cs only type-checks
		if (pairs.length == 0 || !FileSystem.exists(dir)) return;
		var wanted = new Map<String, Array<{iface:String, cls:String, params:Array<String>}>>();
		for (p in pairs) {
			var cut = p.cls + "<" + p.params.join(", ") + ">();";
			if (!wanted.exists(cut)) wanted.set(cut, []);
			wanted.get(cut).push(p);
		}
		walk(dir, wanted);
	}

	static function walk(dir:String, wanted:Map<String, Array<{iface:String, cls:String, params:Array<String>}>>):Void {
		for (entry in FileSystem.readDirectory(dir)) {
			var full = Path.join([dir, entry]);
			if (FileSystem.isDirectory(full)) {
				walk(full, wanted);
				continue;
			}
			if (Path.extension(entry) != "cs") continue;
			var text = File.getContent(full);
			if (text.indexOf("_cast<") < 0) continue;
			var fixed = text;
			for (cut => list in wanted) {
				if (fixed.indexOf(cut) < 0) continue;
				for (p in list) {
					var renamed = [for (n in p.params) n + "_c"].join(", ");
					// The forwarder: its header, an optional #line, then the wrong call.
					var forwarder = new EReg("(public virtual object " + p.iface + "<" + renamed + ">\\(\\) \\{\\s*(?:#line[^\\n]*\\n\\s*)?return this\\.)" + p.cls
						+ "<" + p.params.join(", ") + ">\\(\\);", "g");
					fixed = forwarder.replace(fixed, "$1" + p.cls + "<" + renamed + ">();");
				}
			}
			if (fixed != text) File.saveContent(full, fixed);
		}
	}

	static function sameParams(args:Array<Type>, params:Array<TypeParameter>):Bool {
		if (args.length != params.length) return false;
		for (i in 0...args.length) {
			switch (args[i]) {
				case TInst(_.get() => p, []) if (p.kind.match(KTypeParameter(_)) && p.name == params[i].name):
				case _: return false;
			}
		}
		return true;
	}

	/** The name Haxe gives a type's cast method: its path, underscored, then `_cast`. **/
	static function castName(c:ClassType):String {
		return c.pack.concat([c.name]).join("_") + "_cast";
	}
}
#end
