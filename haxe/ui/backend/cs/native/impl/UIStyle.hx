package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.UIImage;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;

/** One brush made for a border colour, under the opacity and colour filter it was made for. */
@:native("HaxeUICs.UIStyleBorderBrush")
@:nativeGen
class UIStyleBorderBrush {
	public final Color:UInt;
	public final Opacity:Float;
	public final Matrix:NativeArray<Single>;
	public final Brush:IBrush;

	public function new(color:UInt, opacity:Float, matrix:NativeArray<Single>, brush:IBrush) {
		Color = color;
		Opacity = opacity;
		Matrix = matrix;
		Brush = brush;
	}
}

/**
 * The HaxeUI style values a UIPanel paints, filled in by haxe.ui.backend.cs.StyleMapper.
 * Colours are ARGB; 0 (alpha 0) means "none".
 */
@:native("HaxeUICs.UIStyle")
@:nativeGen
class UIStyle {
	public function new() {}

	public var BackgroundColor:UInt = 0;
	public var BackgroundColorEnd:UInt = 0;

	/** 0 none, 1 vertical, 2 horizontal. */
	public var GradientStyle:Int = 0;

	public var BackgroundOpacity:Float = 1;

	public var BorderLeft:Float = 0;
	public var BorderTop:Float = 0;
	public var BorderRight:Float = 0;
	public var BorderBottom:Float = 0;
	public var BorderLeftColor:UInt = 0;
	public var BorderTopColor:UInt = 0;
	public var BorderRightColor:UInt = 0;
	public var BorderBottomColor:UInt = 0;
	public var BorderOpacity:Float = 1;

	/** 0 solid, 1 dashed, 2 dotted. */
	public var BorderStyle:Int = 0;

	public var RadiusTL:Float = 0;
	public var RadiusTR:Float = 0;
	public var RadiusBR:Float = 0;
	public var RadiusBL:Float = 0;

	public var Opacity:Float = 1;
	public var Cursor:String;

	/** CSS filter: blur(n), in px; 0 for none. It blurs the panel and everything in it. */
	public var Blur:Float = 0;

	/** Box shadows around (or, inset, inside) the background's rounded rect. */
	public var Shadows:BoxShadows;

	final _shadows = new Array<BoxShadow>();

	public function ClearShadows():Void {
		_shadows.resize(0);
		Shadows = new BoxShadows();
	}

	/** `argb`: the colour, its alpha the shadow's opacity. */
	public function AddShadow(offsetX:Float, offsetY:Float, blur:Float, spread:Float, argb:UInt, inset:Bool):Void {
		var shadow = new BoxShadow();
		shadow.OffsetX = offsetX;
		shadow.OffsetY = offsetY;
		shadow.Blur = Math.max(0, blur);
		shadow.Spread = Math.max(0, spread);
		shadow.Color = Color.FromUInt32(argb);
		shadow.IsInset = inset;
		_shadows.push(shadow);
		Shadows = ShadowsOf(_shadows);
	}

	static function ShadowsOf(shadows:Array<BoxShadow>):BoxShadows {
		if (shadows.length == 1) {
			return new BoxShadows(shadows[0]);
		}
		var rest = new NativeArray<BoxShadow>(shadows.length - 1);
		for (i in 1...shadows.length) {
			rest[i - 1] = shadows[i];
		}
		return new BoxShadows(shadows[0], rest);
	}

	public var BackgroundImage:UIImage;

	/** Source rect within the image (left, top, right, bottom); NaN: the whole image. */
	public var ClipL:Float = Math.NaN;

	public var ClipT:Float = Math.NaN;
	public var ClipR:Float = Math.NaN;
	public var ClipB:Float = Math.NaN;

	/** The 9-slice centre rect within the (clipped) source (left, top, right, bottom); NaN: no slicing. */
	public var SliceL:Float = Math.NaN;

	public var SliceT:Float = Math.NaN;
	public var SliceR:Float = Math.NaN;
	public var SliceB:Float = Math.NaN;

	/** 0 stretch, 1 repeat, 2 natural size. With a slice, repeat tiles the edges and centre. */
	public var Repeat:Int = 0;

	/** background-width/-height in px, or in percent of the panel; NaN when not given. */
	public var BgWidth:Float = Math.NaN;

	public var BgHeight:Float = Math.NaN;
	public var BgWidthPercent:Float = Math.NaN;
	public var BgHeightPercent:Float = Math.NaN;

	/** image-rendering: pixelated (no smoothing when scaled). */
	public var Pixelated:Bool = false;

	@:property public var HasClip(get, never):Bool;

	function get_HasClip():Bool {
		return !Math.isNaN(ClipL) && !Math.isNaN(ClipT) && !Math.isNaN(ClipR) && !Math.isNaN(ClipB);
	}

	@:property public var HasSlice(get, never):Bool;

	function get_HasSlice():Bool {
		return !Math.isNaN(SliceL) && !Math.isNaN(SliceT) && !Math.isNaN(SliceR) && !Math.isNaN(SliceB);
	}

	/** The colour filter in force while this style is painted (set by UIPainter), or null. */
	public var PaintMatrix:NativeArray<Single>;

	// Brushes are kept between renders and made again only when what they show changes.
	var _background:IBrush;
	var _backgroundMade = false;
	var _madeColor:UInt = 0;
	var _madeColorEnd:UInt = 0;
	var _madeGradient = 0;
	var _madeOpacity = 0.0;
	var _madeMatrix:NativeArray<Single>;
	final _borders = new Array<UIStyleBorderBrush>();

	public function BackgroundBrush():IBrush {
		if (!_backgroundMade || _madeColor != BackgroundColor || _madeColorEnd != BackgroundColorEnd || _madeGradient != GradientStyle
			|| _madeOpacity != BackgroundOpacity || _madeMatrix != PaintMatrix) {
			_background = ColorMatrix.Brush(UnfilteredBackgroundBrush(), PaintMatrix);
			_madeColor = BackgroundColor;
			_madeColorEnd = BackgroundColorEnd;
			_madeGradient = GradientStyle;
			_madeOpacity = BackgroundOpacity;
			_madeMatrix = PaintMatrix;
			_backgroundMade = true;
		}
		return _background;
	}

	/** The shadows, their colours through the paint-time colour filter. */
	public function PaintShadows():BoxShadows {
		if (PaintMatrix == null || _shadows.length == 0) {
			return Shadows;
		}
		var mapped = new Array<BoxShadow>();
		for (shadow in _shadows) {
			var copy = shadow;
			copy.Color = ColorMatrix.Apply(PaintMatrix, copy.Color);
			mapped.push(copy);
		}
		return ShadowsOf(mapped);
	}

	function UnfilteredBackgroundBrush():IBrush {
		if (BackgroundColor == 0) {
			return null;
		}
		if (GradientStyle == 0 || BackgroundColorEnd == 0) {
			return new SolidColorBrush(Color.FromUInt32(BackgroundColor), BackgroundOpacity);
		}
		var horizontal = GradientStyle == 2;
		var stops = new GradientStops();
		stops.Add(new GradientStop(Color.FromUInt32(BackgroundColor), 0));
		stops.Add(new GradientStop(Color.FromUInt32(BackgroundColorEnd), 1));
		var brush = new LinearGradientBrush();
		brush.StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative);
		brush.EndPoint = horizontal ? new RelativePoint(1, 0, RelativeUnit.Relative) : new RelativePoint(0, 1, RelativeUnit.Relative);
		brush.GradientStops = stops;
		brush.Opacity = BackgroundOpacity;
		return brush;
	}

	public function BorderBrush(color:UInt):IBrush {
		if (color == 0) {
			return null;
		}
		for (made in _borders) {
			if (made.Color == color && made.Opacity == BorderOpacity && made.Matrix == PaintMatrix) {
				return made.Brush;
			}
		}
		if (_borders.length >= 8) {
			_borders.resize(0); // a style shows at most four border colours
		}
		var brush = ColorMatrix.Brush(new SolidColorBrush(Color.FromUInt32(color), BorderOpacity), PaintMatrix);
		_borders.push(new UIStyleBorderBrush(color, BorderOpacity, PaintMatrix, brush));
		return brush;
	}

	/** The pen for a border line of this width, dashed or dotted as BorderStyle says. */
	public function BorderPen(brush:IBrush, width:Float):Pen {
		// Dash lengths are in multiples of the pen's width: dashes of 3 with gaps of 3, as
		// browsers draw them; dots are round caps on zero-length dashes, a dot apart.
		return switch (BorderStyle) {
			case 1: new Pen(brush, width, Dashes(3, 3), PenLineCap.Flat, PenLineJoin.Miter, 10);
			case 2: new Pen(brush, width, Dashes(0, 2), PenLineCap.Round, PenLineJoin.Miter, 10);
			default: new Pen(brush, width, null, PenLineCap.Flat, PenLineJoin.Miter, 10);
		}
	}

	static function Dashes(dash:Float, gap:Float):DashStyle {
		var lengths = new NativeArray<Float>(2);
		lengths[0] = dash;
		lengths[1] = gap;
		return new DashStyle(cast lengths, 0);
	}

	@:property public var HasRadius(get, never):Bool;

	function get_HasRadius():Bool {
		return RadiusTL > 0 || RadiusTR > 0 || RadiusBR > 0 || RadiusBL > 0;
	}

	@:property public var UniformBorder(get, never):Bool;

	function get_UniformBorder():Bool {
		return BorderLeft == BorderTop && BorderTop == BorderRight && BorderRight == BorderBottom && BorderLeftColor == BorderTopColor
			&& BorderTopColor == BorderRightColor && BorderRightColor == BorderBottomColor;
	}

	/** CSS cursor names, as the Avalonia cursor that stands in for each. */
	static var CursorTypes:Map<String, StandardCursorType> = [
		"default" => StandardCursorType.Arrow,
		"auto" => StandardCursorType.Arrow,
		"pointer" => StandardCursorType.Hand,
		"text" => StandardCursorType.Ibeam,
		"vertical-text" => StandardCursorType.Ibeam,
		"move" => StandardCursorType.SizeAll,
		"all-scroll" => StandardCursorType.SizeAll,
		"none" => StandardCursorType.None,
		"not-allowed" => StandardCursorType.No,
		"no-drop" => StandardCursorType.No,
		"wait" => StandardCursorType.Wait,
		"progress" => StandardCursorType.AppStarting,
		"crosshair" => StandardCursorType.Cross,
		"help" => StandardCursorType.Help,
		"grab" => StandardCursorType.Hand,
		"grabbing" => StandardCursorType.DragMove,
		"copy" => StandardCursorType.DragCopy,
		"alias" => StandardCursorType.DragLink,
		"col-resize" => StandardCursorType.SizeWestEast,
		"ew-resize" => StandardCursorType.SizeWestEast,
		"row-resize" => StandardCursorType.SizeNorthSouth,
		"ns-resize" => StandardCursorType.SizeNorthSouth,
		"nwse-resize" => StandardCursorType.TopLeftCorner,
		"nesw-resize" => StandardCursorType.TopRightCorner,
		"n-resize" => StandardCursorType.TopSide,
		"s-resize" => StandardCursorType.BottomSide,
		"e-resize" => StandardCursorType.RightSide,
		"w-resize" => StandardCursorType.LeftSide,
		"nw-resize" => StandardCursorType.TopLeftCorner,
		"se-resize" => StandardCursorType.BottomRightCorner,
		"ne-resize" => StandardCursorType.TopRightCorner,
		"sw-resize" => StandardCursorType.BottomLeftCorner
	];

	/** The Avalonia StandardCursorType name for a CSS cursor, or null when it has none. */
	public static function StandardCursorName(css:String):String {
		return css != null && CursorTypes.exists(css) ? (cast CursorTypes.get(css) : cs.system.Object).ToString() : null;
	}

	public static function CursorFor(name:String):Cursor {
		return name != null && CursorTypes.exists(name) ? new Cursor(CursorTypes.get(name)) : null;
	}
}
