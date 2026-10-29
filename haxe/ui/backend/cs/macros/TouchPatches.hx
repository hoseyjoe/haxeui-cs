package haxe.ui.backend.cs.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * HaxeUI for a touch screen, on Android only (Build.configure runs this with
 * `-D haxeui_cs_android`): `ToolTipManager.registerTooltip` arms no hover tooltip and installs
 * touch/TouchTooltips instead, so a long press shows a component's `tooltip`.
 *
 * A finger has no hover: a tap's jitter or a scroll reaches the control under it as a move, it
 * gets MOUSE_OVER, and with no pointer left to raise MOUSE_OUT its tooltip came up after the
 * finger had lifted. The options are still kept, because a component's `tooltip` getter reads
 * them back. The same patch as heaps-android's AndroidPatches.noHoverTooltips.
 */
class TouchPatches {
	public static function init():Void {
		haxe.macro.Compiler.addMetadata("@:build(haxe.ui.backend.cs.macros.TouchPatches.noHoverTooltips())", "haxe.ui.tooltips.ToolTipManager");
	}

	public static function noHoverTooltips():Array<Field> {
		var fields = Context.getBuildFields();
		for (f in fields) {
			if (f.name != "registerTooltip") continue;
			switch (f.kind) {
				case FFun(fn):
					fn.expr = macro {
						if (_toolTipOptions.exists(target)) return;
						if (options == null) options = {};
						if (options.tipData == null) options.tipData = {text: target.tooltip};
						_toolTipOptions.set(target, options);
						haxe.ui.backend.cs.touch.TouchTooltips.install();
					};
					return fields;
				default:
			}
		}
		Context.warning('haxeui-cs: ${Context.getLocalClass()} has no function registerTooltip to patch', Context.currentPos());
		return fields;
	}
}
#end
