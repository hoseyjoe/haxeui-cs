package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.UIStyle;
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

		var radius = or(style.borderRadius, 0);
		into.RadiusTL = or(style.borderRadiusTopLeft, radius);
		into.RadiusTR = or(style.borderRadiusTopRight, radius);
		into.RadiusBR = or(style.borderRadiusBottomRight, radius);
		into.RadiusBL = or(style.borderRadiusBottomLeft, radius);

		into.Opacity = or(style.opacity, 1);
		into.Cursor = style.cursor;
	}

	static inline function or(value:Null<Float>, fallback:Float):Float {
		return value != null ? value : fallback;
	}

	/** HaxeUI colours are 0xRRGGBB; the native side takes opaque ARGB, with 0 meaning none. **/
	static function color(value:Null<Int>):UInt {
		return value == null ? 0 : cast(0xFF000000 | (value & 0xFFFFFF));
	}
}
