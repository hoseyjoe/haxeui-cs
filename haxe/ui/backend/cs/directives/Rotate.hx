package haxe.ui.backend.cs.directives;

import haxe.ui.core.Component;
import haxe.ui.styles.DirectiveHandler;
import haxe.ui.styles.elements.Directive;

/** `rotation: <degrees>`, as haxeui-html5 has it: the component turned about its centre. **/
class Rotate extends DirectiveHandler {
	public override function apply(component:Component, directive:Directive) {
		switch (directive.value) {
			case VNone:
				component.nativePanel.SetRotation(0);
			case VNumber(v):
				component.nativePanel.SetRotation(v);
			case _:
		}
	}
}
