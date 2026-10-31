package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.IntPtr;
import cs.system.Nullable_1;
import cs.system.text.Encoding;
import cs.system.text.regularexpressions.Match;
import cs.system.text.regularexpressions.MatchEvaluator;
import cs.system.text.regularexpressions.Regex;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Skia;

/** A decoded image: HaxeUI's ImageData. */
@:native("HaxeUICs.UIImage")
@:nativeGen
class UIImage {
	final _bitmap:Bitmap;
	var _svg:SKSvg; // owns the picture
	var _picture:SKPicture;
	final _svgText:String; // as authored, for drawing again in another palette
	var _paletteVersion = 0;
	final _rasters = new Map<Int, Bitmap>();
	final _rasterOrder = new Array<Int>();

	static var _palette:Map<Int, Int>;
	static var _currentPaletteVersion = 0;

	/**
	 * Recolours every SVG image, on screen and from now on: each #rrggbb (or #rgb) colour in
	 * `from` is drawn as the one at the same index in `to`, as heaps-svg's SvgIcons.setPalette
	 * does for a theme's icons. Null or empty arrays draw them as authored.
	 */
	public static function SetPalette(from:NativeArray<Int>, to:NativeArray<Int>):Void {
		var palette:Map<Int, Int> = null;
		if (from != null && to != null && from.Length > 0) {
			palette = new Map<Int, Int>();
			for (i in 0...(from.Length < to.Length ? from.Length : to.Length)) {
				palette.set(from[i] & 0xFFFFFF, to[i] & 0xFFFFFF);
			}
		}
		_palette = palette;
		_currentPaletteVersion++;
		var visuals = VisualTreeExtensions.GetVisualDescendants(Host.Root).GetEnumerator();
		while (visuals.MoveNext()) {
			visuals.Current.InvalidateVisual();
		}
		visuals.Dispose();
		Host.Root.InvalidateVisual();
	}

	static final HexColour = new Regex("(?<!url\\()#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-fA-F])");

	/** The SVG's text with the palette's colours in place of its own. */
	static function Recolour(svg:String):String {
		var palette = _palette;
		if (palette == null) {
			return svg;
		}
		var evaluator:MatchEvaluator = function(m:Match):String {
			var hex = m.Groups[1].Value;
			if (hex.length == 3) {
				var r = hex.charAt(0), g = hex.charAt(1), b = hex.charAt(2);
				hex = r + r + g + g + b + b;
			}
			var rgb = cs.system.Convert.ToInt32(hex, 16);
			return palette.exists(rgb) ? "#" + StringTools.hex(palette.get(rgb), 6).toLowerCase() : m.Value;
		};
		return HexColour.Replace(svg, evaluator);
	}

	static function Parse(svgText:String):SKSvg {
		var svg = new SKSvg();
		var stream = new MemoryStream(Encoding.UTF8.GetBytes(Recolour(svgText)));
		Scope.run(stream, () -> svg.Load(stream));
		return svg;
	}

	/**
	 * Device pixels per layout unit where a visual draws: the screen's render scaling times any
	 * scale on the way to the window (Toolkit.scale), so vector images are drawn for that size.
	 */
	public static function DeviceScale(visual:Visual):Float {
		var top = TopLevel.GetTopLevel(visual);
		if (top == null) {
			return 1;
		}
		var scale = top.RenderScaling;
		var m = VisualExtensions.TransformToVisual(visual, top);
		if (m.HasValue) {
			var value = m.Value;
			scale *= Math.sqrt(value.M11 * value.M11 + value.M12 * value.M12);
		}
		return scale;
	}

	/** The image at its own size (a vector image drawn at its intrinsic size). */
	@:property public var Bitmap(get, never):Bitmap;

	function get_Bitmap():Bitmap {
		return _bitmap != null ? _bitmap : BitmapFor(Width, Height);
	}

	public final Width:Int;
	public final Height:Int;

	@:property public var IsVector(get, never):Bool;

	function get_IsVector():Bool {
		return _picture != null;
	}

	/** How many drawn sizes of a vector image are kept. */
	public var CachedSizes(get, never):Int;

	function get_CachedSizes():Int {
		return _rasterOrder.length;
	}

	function new(bitmap:Bitmap, svg:SKSvg, picture:SKPicture, svgText:String) {
		_bitmap = bitmap;
		_svg = svg;
		_picture = picture;
		_svgText = svgText;
		if (bitmap != null) {
			Width = bitmap.PixelSize.Width;
			Height = bitmap.PixelSize.Height;
		} else {
			_paletteVersion = _currentPaletteVersion;
			var cull = picture.CullRect;
			Width = AtLeastOne(Math.ceil(cull.Width));
			Height = AtLeastOne(Math.ceil(cull.Height));
		}
	}

	static function AtLeastOne(n:Int):Int {
		return n < 1 ? 1 : n;
	}

	/** Decodes PNG/JPEG/etc. or SVG bytes; null when they are not an image. */
	public static function FromBytes(data:NativeArray<UInt8>):UIImage {
		if (data == null || data.Length == 0) {
			return null;
		}
		if (LooksLikeSvg(data)) {
			return FromSvg(data);
		}
		try {
			var stream = new MemoryStream(data);
			return Scope.get(stream, () -> new UIImage(new Bitmap(stream), null, null, null));
		} catch (e:Dynamic) {
			return null;
		}
	}

	static function LooksLikeSvg(data:NativeArray<UInt8>):Bool {
		var head = Encoding.UTF8.GetString(data, 0, data.Length < 1024 ? data.Length : 1024);
		var start = 0;
		while (start < head.length && IsSkipped(head.charCodeAt(start))) {
			start++;
		}
		head = head.substr(start);
		return StringTools.startsWith(head, "<svg")
			|| ((StringTools.startsWith(head, "<?xml") || StringTools.startsWith(head, "<!")) && head.indexOf("<svg") >= 0);
	}

	static function IsSkipped(c:Int):Bool {
		return c == 0xFEFF || c == " ".code || c == "\t".code || c == "\r".code || c == "\n".code;
	}

	static function FromSvg(data:NativeArray<UInt8>):UIImage {
		try {
			var text = Encoding.UTF8.GetString(data);
			var svg = Parse(text);
			var picture = svg.Picture;
			if (picture == null || picture.CullRect.Width <= 0 || picture.CullRect.Height <= 0) {
				return null;
			}
			return new UIImage(null, svg, picture, text);
		} catch (e:Dynamic) {
			return null;
		}
	}

	static function Clamped(pixels:Float):Int {
		var n = Math.ceil(pixels);
		return n < 1 ? 1 : n > 4096 ? 4096 : n;
	}

	/**
	 * The bitmap to draw this image at, for about this many device pixels: a raster image is
	 * itself; a vector one is drawn afresh at that size (and kept), so it stays sharp.
	 */
	public function BitmapFor(pixelWidth:Float, pixelHeight:Float):Bitmap {
		if (_bitmap != null) {
			return _bitmap;
		}
		if (_paletteVersion != _currentPaletteVersion) {
			// the palette changed since this was drawn: drawn again in the new one
			_paletteVersion = _currentPaletteVersion;
			try {
				var svg = Parse(_svgText);
				var picture = svg.Picture;
				if (picture != null) {
					if (_svg != null) {
						_svg.Dispose();
					}
					_svg = svg;
					_picture = picture;
				}
			} catch (e:Dynamic) {} // kept in the old colours
			_rasters.clear();
			_rasterOrder.resize(0);
		}
		var w = Clamped(pixelWidth);
		var h = Clamped(pixelHeight);
		var key = w * 8192 + h;
		if (_rasters.exists(key)) {
			return _rasters.get(key);
		}
		// A resize asks for a new size every frame: keep only the last two.
		if (_rasterOrder.length >= 2) {
			_rasters.remove(_rasterOrder.shift());
		}
		var raster = new SKBitmap(new SKImageInfo(w, h, SKColorType.Bgra8888, SKAlphaType.Premul));
		var result = Scope.get(raster, () -> {
			var canvas = new SKCanvas(raster);
			Scope.run(canvas, () -> {
				canvas.Clear(SKColors.Transparent);
				var cull = _picture.CullRect;
				canvas.Scale(w / cull.Width, h / cull.Height);
				canvas.Translate(-cull.Left, -cull.Top);
				canvas.DrawPicture(_picture, null);
			});
			var written = new WriteableBitmap(new PixelSize(w, h), new Vector(96, 96), new Nullable_1(PixelFormat.Bgra8888), new Nullable_1(AlphaFormat.Premul));
			var buffer = written.Lock();
			Scope.run(buffer, () -> {
				var bytes = raster.Bytes;
				for (row in 0...h) {
					Marshal.Copy(bytes, row * raster.RowBytes, IntPtr.Add(buffer.Address, row * buffer.RowBytes), w * 4);
				}
			});
			return written;
		});
		_rasters.set(key, result);
		_rasterOrder.push(key);
		return result;
	}
}

/** A HaxeUI image display: draws its image stretched to the size HaxeUI gives it. */
@:native("HaxeUICs.UIImageView")
@:nativeGen
class UIImageView extends Control implements IColorFiltered {
	var _image:UIImage;
	var _matrix:NativeArray<Single>;

	public function SetEffectiveColorMatrix(matrix:NativeArray<Single>):Void {
		_matrix = matrix;
		InvalidateVisual();
	}

	public var W(default, null):Float = 0;
	public var H(default, null):Float = 0;

	public function new() {
		super();
		IsHitTestVisible = false;
	}

	public function SetImage(image:UIImage):Void {
		_image = image;
		InvalidateVisual();
	}

	/** image-rendering: pixelated: scaled without smoothing. */
	public function SetPixelated(pixelated:Bool):Void {
		RenderOptions.SetBitmapInterpolationMode(this, pixelated ? BitmapInterpolationMode.None : BitmapInterpolationMode.Unspecified);
		InvalidateVisual();
	}

	/** Sets position and size; NaN leaves that value as it was. */
	public function SetBounds(left:Float, top:Float, width:Float, height:Float):Void {
		if (!Math.isNaN(left)) {
			Canvas.SetLeft(this, left);
		}
		if (!Math.isNaN(top)) {
			Canvas.SetTop(this, top);
		}
		if (!Math.isNaN(width)) {
			Width = W = Math.max(0, width);
		}
		if (!Math.isNaN(height)) {
			Height = H = Math.max(0, height);
		}
	}

	/** Only the given rect (in this view's own coordinates) shows. */
	public function SetClip(enabled:Bool, left:Float, top:Float, width:Float, height:Float):Void {
		Clip = enabled ? new RectangleGeometry(new Rect(left, top, Math.max(0, width), Math.max(0, height))) : null;
	}

	override public function Render(context:DrawingContext):Void {
		if (_image == null || W <= 0 || H <= 0) {
			return;
		}
		var scale = UIImage.DeviceScale(this);
		var bitmap = ColorMatrix.Filter(_image.BitmapFor(W * scale, H * scale), _matrix);
		context.DrawImage(bitmap, new Rect(0, 0, bitmap.PixelSize.Width, bitmap.PixelSize.Height), new Rect(0, 0, W, H));
	}
}
