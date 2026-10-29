package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.UIImage;

/**
 * Recolours SVG images, as heaps-svg's `SvgIcons.setPalette` does: an app's icons drawn in one
 * colour are shown in another under a dark theme, without a second set of files.
 *
 *     SvgPalette.set([0x555B66 => 0xFFFFFF]); // on every theme change; null for as authored
 */
class SvgPalette {
	/**
	 * Every `#rrggbb` (or `#rgb`) colour among the keys, drawn as its value (0xRRGGBB both), in the
	 * SVG images on screen and in those shown from now on. Other colours are kept.
	 */
	public static function set(palette:Null<Map<Int, Int>>):Void {
		var from = new Array<Int>();
		var to = new Array<Int>();
		if (palette != null) {
			for (k in palette.keys()) {
				from.push(k);
				to.push(palette.get(k));
			}
		}
		UIImage.SetPalette(cs.Lib.nativeArray(from, true), cs.Lib.nativeArray(to, true));
	}
}
