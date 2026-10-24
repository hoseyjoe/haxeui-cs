package haxe.ui.backend.cs.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * StringTools.startsWith / endsWith compared as every other Haxe target compares
 * them: code unit by code unit.
 *
 * Haxe 4.3's C# StringTools calls .NET's `StartsWith(string)` / `EndsWith(string)`,
 * which compare by the current culture, and to which a BOM or a soft hyphen is
 * "ignorable": every string starts and ends with one. The usual BOM strip
 * (`if (startsWith(s, "﻿")) s = s.substr(1)`) then cuts a real character off
 * every file. The rest of Haxe's C# std is culture-free already (indexOf is
 * ordinal, case mapping and parseFloat invariant); these two are the outliers.
 *
 * Build.configure hangs this on StringTools as a build macro, so inlined and
 * dynamic calls both get it.
 */
class OrdinalStringTools {
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		for (field in fields) {
			switch (field.kind) {
				case FFun(fn) if (field.name == "startsWith" || field.name == "endsWith"):
					var s = macro $i{fn.args[0].name};
					var other = macro $i{fn.args[1].name};
					fn.expr = field.name == "startsWith"
						? macro return cs.Syntax.code("{0}.StartsWith({1}, global::System.StringComparison.Ordinal)", $s, $other)
						: macro return cs.Syntax.code("{0}.EndsWith({1}, global::System.StringComparison.Ordinal)", $s, $other);
				default:
			}
		}
		return fields;
	}
}
#end
