package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.Host;

/**
 * What an app scales HaxeUI by to get the same physical layout on every phone, and under heaps as
 * under this backend. Avalonia already lays out in its own units, `Host.RenderScaling` device pixels
 * each, so `Toolkit.scale` is what is left after that of the whole-number pixel multiple of the
 * design width that fits the screen's short edge.
 *
 *   Toolkit.scaleX = Toolkit.scaleY = Density.scaleFor(360);  // before the first component
 */
class Density {
	/** The Toolkit scale that makes `designWidth` units span the short edge, in whole device pixels per unit. **/
	public static function scaleFor(designWidth:Float):Float {
		var density = Host.RenderScaling;
		var surface = Math.min(Host.ClientWidth, Host.ClientHeight) * density;
		return Math.max(1, Math.round(surface / designWidth)) / density;
	}
}
