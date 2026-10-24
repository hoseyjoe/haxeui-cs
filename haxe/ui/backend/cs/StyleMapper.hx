package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.UIStyle;
import haxe.ui.filters.Blur;
import haxe.ui.filters.BoxShadow;
import haxe.ui.filters.DropShadow;
import haxe.ui.styles.Style;

/** Copies the HaxeUI style values a native panel paints into its UIStyle. **/
class StyleMapper {
	public static function toNative(style:Style, into:UIStyle):Void {
		into.BackgroundColor = color(style.backgroundColor);
		into.BackgroundColorEnd = color(style.backgroundColorEnd);
		into.GradientStyle = style.backgroundColorEnd == null ? 0 : (style.backgroundGradientStyle == "horizontal" ? 2 : 1);
		into.BackgroundOpacity = or(style.backgroundOpacity, 1);

		into.BorderLeft = or(style.borderLeftSize, or(style.borderSize, 0));
		into.BorderTop = or(style.borderTopSize, or(style.borderSize, 0));
		into.BorderRight = or(style.borderRightSize, or(style.borderSize, 0));
		into.BorderBottom = or(style.borderBottomSize, or(style.borderSize, 0));
		into.BorderLeftColor = color(style.borderLeftColor != null ? style.borderLeftColor : style.borderColor);
		into.BorderTopColor = color(style.borderTopColor != null ? style.borderTopColor : style.borderColor);
		into.BorderRightColor = color(style.borderRightColor != null ? style.borderRightColor : style.borderColor);
		into.BorderBottomColor = color(style.borderBottomColor != null ? style.borderBottomColor : style.borderColor);
		into.BorderOpacity = or(style.borderOpacity, 1);
		into.BorderStyle = switch (style.borderStyle) {
			case "dashed": 1;
			case "dotted": 2;
			case _: 0;
		};

		var radius = or(style.borderRadius, 0);
		into.RadiusTL = or(style.borderRadiusTopLeft, radius);
		into.RadiusTR = or(style.borderRadiusTopRight, radius);
		into.RadiusBR = or(style.borderRadiusBottomRight, radius);
		into.RadiusBL = or(style.borderRadiusBottomLeft, radius);

		into.Opacity = or(style.opacity, 1);
		into.Cursor = style.cursor;

		into.ClearShadows();
		into.Blur = 0;
		if (style.filter != null) {
			for (f in style.filter) {
				shadow(f, into);
				if ((f is Blur)) {
					into.Blur = Math.max(0, (cast f : Blur).amount);
				}
			}
		}

		// the image itself is loaded by ComponentImpl.applyStyle; these say how to draw it
		into.ClipL = or(style.backgroundImageClipLeft, Math.NaN);
		into.ClipT = or(style.backgroundImageClipTop, Math.NaN);
		into.ClipR = or(style.backgroundImageClipRight, Math.NaN);
		into.ClipB = or(style.backgroundImageClipBottom, Math.NaN);
		into.SliceL = or(style.backgroundImageSliceLeft, Math.NaN);
		into.SliceT = or(style.backgroundImageSliceTop, Math.NaN);
		into.SliceR = or(style.backgroundImageSliceRight, Math.NaN);
		into.SliceB = or(style.backgroundImageSliceBottom, Math.NaN);
		into.Repeat = switch (style.backgroundImageRepeat) {
			case "repeat": 1;
			case null | "stretch": 0;
			case _: 2;
		};
		into.BgWidth = or(style.backgroundWidth, Math.NaN);
		into.BgHeight = or(style.backgroundHeight, Math.NaN);
		into.BgWidthPercent = or(style.backgroundWidthPercent, Math.NaN);
		into.BgHeightPercent = or(style.backgroundHeightPercent, Math.NaN);
		into.Pixelated = style.imageRendering == "pixelated";
	}

	/**
	 * Shadows as html5 draws them (its FilterHelper): a box shadow on the component's box.
	 * A drop-shadow's angle, strength and quality are ignored there too.
	 */
	static function shadow(f:haxe.ui.filters.Filter, into:UIStyle) {
		if ((f is DropShadow)) {
			var d:DropShadow = cast f;
			if (d.inner) {
				into.AddShadow(d.distance, d.distance, d.blurX, 0, withAlpha(d.color, d.alpha), true);
			} else {
				into.AddShadow(d.distance, d.distance + 2, d.blurX - 1, d.blurY - 1, withAlpha(d.color, d.alpha), false);
			}
		} else if ((f is BoxShadow)) {
			var b:BoxShadow = cast f;
			into.AddShadow(b.offsetX, b.offsetY, b.blurRadius, b.spreadRadius, withAlpha(b.color, b.alpha), b.inset);
		}
	}

	static function withAlpha(rgb:Int, alpha:Float):UInt {
		var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
		return cast((a << 24) | (rgb & 0xFFFFFF));
	}

	static inline function or(value:Null<Float>, fallback:Float):Float {
		return value != null ? value : fallback;
	}

	/** HaxeUI colours are 0xRRGGBB; the native side takes opaque ARGB, with 0 meaning none. **/
	static function color(value:Null<Int>):UInt {
		return value == null ? 0 : cast(0xFF000000 | (value & 0xFFFFFF));
	}
}
