package haxe.ui.backend.cs.directives;

import haxe.ui.core.Component;
import haxe.ui.styles.DirectiveHandler;
import haxe.ui.styles.Value;
import haxe.ui.styles.elements.Directive;

/**
 * `line-height: <number> | <n>px | <n>% | normal`, a haxeui-cs directive for the distance between
 * the lines of a component's text, read as CSS reads it: a bare number or a percentage is of the
 * font size, so `1.5` is half as much again. Core has no line-height (nor letter-spacing), so no
 * backend draws one; other backends ignore this.
 *
 * Registered so that core keeps the directive in a component's style; the text display reads
 * it from there (TextDisplayImpl), as it does text-shadow.
 */
class LineHeight extends DirectiveHandler {
	public override function apply(component:Component, directive:Directive) {
	}

	/** The line height in units for text of `fontSize`, or 0 for the font's own (`normal`, or a value it cannot read). **/
	public static function parse(value:Value, fontSize:Float):Float {
		return switch (value) {
			case VNumber(v) if (v > 0): v * fontSize;
			case VDimension(PX(v)) if (v > 0): v;
			case VDimension(PERCENT(v)) if (v > 0): v / 100 * fontSize;
			case _: 0;
		}
	}
}
