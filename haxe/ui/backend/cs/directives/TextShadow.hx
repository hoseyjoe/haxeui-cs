package haxe.ui.backend.cs.directives;

import haxe.ui.core.Component;
import haxe.ui.styles.DirectiveHandler;
import haxe.ui.styles.Value;
import haxe.ui.styles.elements.Directive;

/**
 * `text-shadow: <dx>px <dy>px <blur>px <#rrggbb> [<alpha 0..1>]`, a haxeui-cs directive that
 * shadows the glyphs of a component's text. Core has no text-shadow, and html5's drop-shadow
 * shadows the box, not the glyphs. Other backends ignore it.
 *
 * Registered so that core keeps the directive in a component's style; the text display reads
 * it from there (TextDisplayImpl), so the shadow follows the text whenever that is made.
 */
class TextShadow extends DirectiveHandler {
	public override function apply(component:Component, directive:Directive) {
	}

	/** The shadow a directive's value asks for, or null for none (or a value it cannot read). **/
	public static function parse(value:Value):Null<{dx:Float, dy:Float, blur:Float, argb:UInt}> {
		var parts = switch (value) {
			case null | VNone: return null;
			case VComposite(vl): vl;
			case _: [value];
		}
		var lengths:Array<Float> = [];
		var color:Null<Int> = null;
		var alpha = 1.0;
		for (part in parts) {
			switch (part) {
				case VDimension(PX(v)) | VNumber(v) if (color == null):
					lengths.push(v);
				case VNumber(v):
					alpha = v;
				case VColor(c):
					color = c;
				case _:
					return null;
			}
		}
		if (lengths.length < 2 || color == null) {
			return null;
		}
		var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
		return {
			dx: lengths[0],
			dy: lengths[1],
			blur: lengths.length > 2 ? lengths[2] : 0,
			argb: cast((a << 24) | (color & 0xFFFFFF))
		};
	}
}
