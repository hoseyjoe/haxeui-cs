package haxe.ui.backend.cs;

import haxe.ui.filters.Brightness;
import haxe.ui.filters.Contrast;
import haxe.ui.filters.Filter;
import haxe.ui.filters.Grayscale;
import haxe.ui.filters.HueRotate;
import haxe.ui.filters.Invert;
import haxe.ui.filters.Saturate;
import haxe.ui.filters.Tint;

/**
 * HaxeUI's colour filters as one 4x5 colour matrix (row-major, offsets in 0..1), composed in
 * the order the style lists them. The numbers are CSS's filter functions, which is what html5
 * hands them to; tint is html5's own SVG matrix (its FilterHelper.tintToSvg).
 */
class ColorFilters {
	// CIE luma weights, as html5's tint uses them
	static inline var LUMA_R = 0.212671;
	static inline var LUMA_G = 0.71516;
	static inline var LUMA_B = 0.072169;

	/** The matrix for a style's filters, or null when none of them change colour. **/
	public static function matrixFor(filters:Array<Filter>):cs.NativeArray<Single> {
		if (filters == null) {
			return null;
		}
		var result:Array<Float> = null;
		for (f in filters) {
			var m = matrixOf(f);
			if (m != null) {
				result = result == null ? m : compose(m, result);
			}
		}
		if (result == null) {
			return null;
		}
		var native = new cs.NativeArray<Single>(20);
		for (i in 0...20) {
			native[i] = result[i];
		}
		return native;
	}

	static function matrixOf(f:Filter):Array<Float> {
		if ((f is Grayscale)) {
			var a = clamp((cast f : Grayscale).amount / 100), k = 1 - a;
			return [
				0.2126 + 0.7874 * k, 0.7152 - 0.7152 * k, 0.0722 - 0.0722 * k, 0, 0,
				0.2126 - 0.2126 * k, 0.7152 + 0.2848 * k, 0.0722 - 0.0722 * k, 0, 0,
				0.2126 - 0.2126 * k, 0.7152 - 0.7152 * k, 0.0722 + 0.9278 * k, 0, 0,
				0, 0, 0, 1, 0
			];
		}
		if ((f is Saturate)) {
			var s = Math.max(0, (cast f : Saturate).multiplier);
			return [
				0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
				0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
				0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
				0, 0, 0, 1, 0
			];
		}
		if ((f is HueRotate)) {
			var r = (cast f : HueRotate).angleDegree * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
			return [
				0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0,
				0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
				0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
				0, 0, 0, 1, 0
			];
		}
		if ((f is Brightness)) {
			var b = Math.max(0, (cast f : Brightness).multiplier);
			return [b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
		}
		if ((f is Contrast)) {
			var c = Math.max(0, (cast f : Contrast).multiplier), o = 0.5 - 0.5 * c;
			return [c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
		}
		if ((f is Invert)) {
			var a = clamp((cast f : Invert).multiplier), k = 1 - 2 * a;
			return [k, 0, 0, 0, a, 0, k, 0, 0, a, 0, 0, k, 0, a, 0, 0, 0, 1, 0];
		}
		if ((f is Tint)) {
			var t:Tint = cast f;
			var r = ((t.color >> 16) & 0xFF) / 255, g = ((t.color >> 8) & 0xFF) / 255, b = (t.color & 0xFF) / 255;
			var q = 1 - t.amount, rA = t.amount * r, gA = t.amount * g, bA = t.amount * b;
			return [
				q + rA * LUMA_R, rA * LUMA_G, rA * LUMA_B, 0, 0,
				gA * LUMA_R, q + gA * LUMA_G, gA * LUMA_B, 0, 0,
				bA * LUMA_R, bA * LUMA_G, q + bA * LUMA_B, 0, 0,
				0, 0, 0, 1, 0
			];
		}
		return null;
	}

	/** outer after inner, as 5x5 matrices whose last row is (0, 0, 0, 0, 1). **/
	static function compose(outer:Array<Float>, inner:Array<Float>):Array<Float> {
		var result = [for (i in 0...20) 0.0];
		for (row in 0...4) {
			for (col in 0...5) {
				var sum = col == 4 ? outer[row * 5 + 4] : 0.0;
				for (k in 0...4) {
					sum += outer[row * 5 + k] * inner[k * 5 + col];
				}
				result[row * 5 + col] = sum;
			}
		}
		return result;
	}

	static inline function clamp(v:Float):Float {
		return Math.max(0, Math.min(1, v));
	}
}
