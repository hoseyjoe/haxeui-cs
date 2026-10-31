package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Action;
import cs.system.IntPtr;
import cs.system.Nullable_1;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.UIImage;
import haxe.ui.backend.cs.native.impl.UILayers;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;

private enum abstract Op(Int) {
	var MoveTo;
	var LineTo;
	var CurveTo;
	var CubicTo;
	var Circle;
	var Rectangle;
	var Stroke;
	var Fill;
	var BeginPath;
	var ClosePath;
	var Image;
}

@:native("HaxeUICs.UIGraphicsCommand")
@:nativeGen
class UIGraphicsCommand {
	public final Op:Int;
	public final A:Float;
	public final B:Float;
	public final C:Float;
	public final D:Float;
	public final E:Float;
	public final F:Float;
	public var Has = false;
	public var Color:UInt = 0;
	public var Image:UIImage;

	public function new(op:Int, a:Float, b:Float, c:Float, d:Float, e:Float, f:Float) {
		Op = op;
		A = a;
		B = b;
		C = c;
		D = d;
		E = e;
		F = f;
	}
}

/**
 * HaxeUI's canvas drawing for one component, recorded as commands and replayed when painted.
 * Fills and strokes follow haxeui-heaps (h2d.Graphics): FillStyle(true, c) begins a fill, and every
 * figure drawn until the fill ends (FillStyle(false), the next FillStyle, or the end) is filled,
 * closed, even without BeginPath. Each MoveTo (or change of fill or stroke) ends the figure, which
 * is then filled on its own and outlined, in drawing order: a later figure covers an earlier
 * outline, and two figures of one fill never cut holes in each other.
 */
@:native("HaxeUICs.UIGraphics")
@:nativeGen
class UIGraphics {
	final _commands = new Array<UIGraphicsCommand>();
	var _pixels:WriteableBitmap;
	var _layers:UILayers;

	/** Called when the drawing changes, so its owner repaints. */
	public var Changed:Action;

	public function new() {}

	/** Retained layers drawn above the commands (made on first use); Clear leaves them be. */
	public var Layers(get, never):UILayers;

	function get_Layers():UILayers {
		if (_layers == null) {
			_layers = new UILayers();
			var changed:Action = function() {
				Notify();
			};
			_layers.Changed = changed;
		}
		return _layers;
	}

	function Notify():Void {
		if (Changed != null) {
			Changed.Invoke();
		}
	}

	public function Clear():Void {
		_commands.resize(0);
		_pixels = null;
		Notify();
	}

	static inline function Make(op:Op, a:Float, b:Float, c:Float, d:Float, e:Float, f:Float):UIGraphicsCommand {
		return new UIGraphicsCommand(cast op, a, b, c, d, e, f);
	}

	public function MoveTo(x:Float, y:Float):Void {
		Add(Make(Op.MoveTo, x, y, 0, 0, 0, 0));
	}

	public function LineTo(x:Float, y:Float):Void {
		Add(Make(Op.LineTo, x, y, 0, 0, 0, 0));
	}

	public function CurveTo(cx:Float, cy:Float, ax:Float, ay:Float):Void {
		Add(Make(Op.CurveTo, cx, cy, ax, ay, 0, 0));
	}

	public function CubicCurveTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, ax:Float, ay:Float):Void {
		Add(Make(Op.CubicTo, c1x, c1y, c2x, c2y, ax, ay));
	}

	public function Circle(x:Float, y:Float, radius:Float):Void {
		Add(Make(Op.Circle, x, y, radius, 0, 0, 0));
	}

	public function Rectangle(x:Float, y:Float, width:Float, height:Float):Void {
		Add(Make(Op.Rectangle, x, y, width, height, 0, 0));
	}

	public function StrokeStyle(has:Bool, argb:UInt, thickness:Float):Void {
		var command = Make(Op.Stroke, thickness, 0, 0, 0, 0, 0);
		command.Has = has;
		command.Color = argb;
		Add(command);
	}

	public function FillStyle(has:Bool, argb:UInt):Void {
		var command = Make(Op.Fill, 0, 0, 0, 0, 0, 0);
		command.Has = has;
		command.Color = argb;
		Add(command);
	}

	public function BeginPath():Void {
		Add(Make(Op.BeginPath, 0, 0, 0, 0, 0, 0));
	}

	public function ClosePath():Void {
		Add(Make(Op.ClosePath, 0, 0, 0, 0, 0, 0));
	}

	public function Image(image:UIImage, x:Float, y:Float, width:Float, height:Float):Void {
		var command = Make(Op.Image, x, y, width, height, 0, 0);
		command.Image = image;
		Add(command);
	}

	static function NewPixels(width:Int, height:Int):WriteableBitmap {
		return new WriteableBitmap(new PixelSize(width, height), new Vector(96, 96), new Nullable_1(PixelFormat.Rgba8888), new Nullable_1(AlphaFormat.Unpremul));
	}

	/** Replaces the canvas's pixel layer: RGBA bytes, width × height. */
	public function SetPixels(rgba:NativeArray<UInt8>, width:Int, height:Int):Void {
		if (rgba == null || width <= 0 || height <= 0 || rgba.Length < width * height * 4) {
			return;
		}
		_pixels = NewPixels(width, height);
		var buffer = _pixels.Lock();
		Scope.run(buffer, () -> {
			for (row in 0...height) {
				Marshal.Copy(rgba, row * width * 4, IntPtr.Add(buffer.Address, row * buffer.RowBytes), width * 4);
			}
		});
		Notify();
	}

	/**
	 * Sets one pixel of the canvas's pixel layer (made at width x height when there is none,
	 * or when the canvas has changed size since).
	 */
	public function SetPixel(x:Int, y:Int, argb:UInt, width:Int, height:Int):Void {
		if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height) {
			return;
		}
		if (_pixels == null || _pixels.PixelSize.Width != width || _pixels.PixelSize.Height != height) {
			_pixels = NewPixels(width, height);
		}
		var buffer = _pixels.Lock();
		try {
			// RGBA bytes, as SetPixels writes them
			var at = IntPtr.Add(buffer.Address, y * buffer.RowBytes + x * 4);
			Marshal.WriteByte(at, cast((argb >> 16) & 0xFF));
			Marshal.WriteByte(IntPtr.Add(at, 1), cast((argb >> 8) & 0xFF));
			Marshal.WriteByte(IntPtr.Add(at, 2), cast(argb & 0xFF));
			Marshal.WriteByte(IntPtr.Add(at, 3), cast(argb >> 24));
		} catch (e:cs.system.Exception) {
			buffer.Dispose();
			throw e;
		}
		buffer.Dispose();
		ColorMatrix.Forget(_pixels); // written in place: any filtered copy is out of date
		Notify();
	}

	function Add(command:UIGraphicsCommand):Void {
		_commands.push(command);
		Notify();
	}

	/** `matrix`: the colour filter in force (null for none): colours and images go through it. */
	public function Render(context:DrawingContext, matrix:NativeArray<Single>):Void {
		if (_pixels != null) {
			context.DrawImage(ColorMatrix.Filter(_pixels, matrix), new Rect(0, 0, _pixels.Size.Width, _pixels.Size.Height));
		}
		if (_commands.length > 0) {
			new UIGraphicsReplay(context, matrix).Run(_commands);
		}
		if (_layers != null) {
			_layers.Render(context, matrix);
		}
	}
}

/** One pass over the commands, everything drawn in order: each figure is filled, then outlined. */
@:native("HaxeUICs.UIGraphicsReplay")
@:nativeGen
class UIGraphicsReplay {
	final _context:DrawingContext;
	final _matrix:NativeArray<Single>;

	var _fill:IBrush;
	var _pen:IPen;
	var _figure:PathFigure;
	var _closed = false;

	var _position:Point;

	public function new(context:DrawingContext, matrix:NativeArray<Single>) {
		_context = context;
		_matrix = matrix;
	}

	function Brush(argb:UInt):IBrush {
		return new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)), 1.0);
	}

	public function Run(commands:Array<UIGraphicsCommand>):Void {
		for (c in commands) {
			switch ((cast c.Op : Op)) {
				case Op.MoveTo:
					Flush();
					_position = new Point(c.A, c.B);
				case Op.LineTo:
					var line = new LineSegment();
					line.Point = new Point(c.A, c.B);
					Segment(line);
					_position = line.Point;
				case Op.CurveTo:
					var curve = new QuadraticBezierSegment();
					curve.Point1 = new Point(c.A, c.B);
					curve.Point2 = new Point(c.C, c.D);
					Segment(curve);
					_position = curve.Point2;
				case Op.CubicTo:
					var cubic = new BezierSegment();
					cubic.Point1 = new Point(c.A, c.B);
					cubic.Point2 = new Point(c.C, c.D);
					cubic.Point3 = new Point(c.E, c.F);
					Segment(cubic);
					_position = cubic.Point3;
				case Op.Circle:
					Flush();
					_context.DrawGeometry(_fill, _pen, new EllipseGeometry(new Rect(c.A - c.C, c.B - c.C, c.C * 2, c.C * 2)));
				case Op.Rectangle:
					Flush();
					_context.DrawGeometry(_fill, _pen, new RectangleGeometry(new Rect(c.A, c.B, c.C, c.D)));
				case Op.Stroke:
					Flush();
					_pen = c.Has ? new Pen(Brush(c.Color), c.A > 0 ? c.A : 1, null, PenLineCap.Flat, PenLineJoin.Miter, 10) : null;
				case Op.Fill:
					Flush();
					_fill = c.Has ? Brush(c.Color) : null;
				case Op.BeginPath:
					Flush();
				case Op.ClosePath:
					// Ends the figure closed; the pen goes back to where it started, as on a canvas.
					if (_figure != null) {
						var start = _figure.StartPoint;
						_closed = true;
						Flush();
						_position = start;
					}
				case Op.Image:
					Flush();
					if (c.Image != null && c.C > 0 && c.D > 0) {
						var bitmap = ColorMatrix.Filter(c.Image.BitmapFor(c.C, c.D), _matrix);
						_context.DrawImage(bitmap, new Rect(0, 0, bitmap.PixelSize.Width, bitmap.PixelSize.Height), new Rect(c.A, c.B, c.C, c.D));
					}
			}
		}
		Flush();
	}

	function Segment(segment:PathSegment):Void {
		if (_fill == null && _pen == null) {
			return;
		}
		if (_figure == null) {
			_figure = new PathFigure();
			_figure.StartPoint = _position;
			_figure.IsClosed = false;
			_figure.IsFilled = true;
			_figure.Segments = new PathSegments();
		}
		_figure.Segments.Add(segment);
	}

	/**
	 * Draws the figure in hand, filled (closed, as a fill always is) and then outlined. The outline
	 * is closed when the figure was, or when it ends where it began, as h2d closes a line.
	 */
	function Flush():Void {
		var figure = _figure;
		var closed = _closed;
		_figure = null;
		_closed = false;
		if (figure == null) {
			return;
		}
		figure.IsClosed = closed || _position.Equals(figure.StartPoint);
		var geometry = new PathGeometry();
		geometry.Figures.Add(figure);
		_context.DrawGeometry(_fill, _pen, geometry);
	}
}
