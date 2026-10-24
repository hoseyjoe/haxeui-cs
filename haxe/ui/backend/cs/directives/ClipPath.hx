package haxe.ui.backend.cs.directives;

import haxe.ui.core.Component;
import haxe.ui.styles.DirectiveHandler;
import haxe.ui.styles.ValueTools;
import haxe.ui.styles.elements.Directive;

/** `clip-path: inset(<top> <right> <bottom> <left>)`, as haxeui-html5 has it. **/
class ClipPath extends DirectiveHandler {
	public override function apply(component:Component, directive:Directive) {
		switch (directive.value) {
			case VNone:
				component.nativePanel.SetClipInset(Math.NaN, 0, 0, 0);
			case VCall(f, vl):
				if (f == "inset") {
					switch (vl[0]) {
						case VComposite(vl):
							component.nativePanel.SetClipInset(ValueTools.calcDimension(vl[0]), ValueTools.calcDimension(vl[1]),
								ValueTools.calcDimension(vl[2]), ValueTools.calcDimension(vl[3]));
						case _:
					}
				}
			case _:
		}
	}
}
