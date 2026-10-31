package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Action;
import cs.system.EventHandler_1;
import cs.system.Exception;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.UIEvents;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;

/**
 * One HaxeUI component's native surface. HaxeUI computes every position and size itself, so
 * this is a Canvas that places itself at the bounds it is given and keeps two groups of children:
 * "content" (the component's own text, image or input, always underneath) and child panels,
 * whose indices match HaxeUI's childComponents.
 */
@:native("HaxeUICs.UIPanel")
@:nativeGen
class UIPanel extends Canvas implements ICustomHitTest {
	var _ownMatrix:NativeArray<Single>;
	var _parentMatrix:NativeArray<Single>;
	var _effectiveMatrix:NativeArray<Single>;

	/** This component's own colour filter (null for none); it reaches everything inside. */
	public function SetColorMatrix(own:NativeArray<Single>):Void {
		_ownMatrix = own;
		UpdateColorMatrix();
	}

	function SetParentColorMatrix(parent:NativeArray<Single>):Void {
		_parentMatrix = parent;
		UpdateColorMatrix();
	}

	function UpdateColorMatrix():Void {
		var effective = ColorMatrix.Compose(_parentMatrix, _ownMatrix);
		if (SameMatrix(effective, _effectiveMatrix)) {
			return;
		}
		_effectiveMatrix = effective;
		var children = Children;
		for (i in 0...children.Count) {
			PassColorMatrix(children[i]);
		}
	}

	function PassColorMatrix(child:Control):Void {
		if (Std.isOfType(child, UIPanel)) {
			(cast child : UIPanel).SetParentColorMatrix(_effectiveMatrix);
		} else if (Std.isOfType(child, IColorFiltered)) {
			(cast child : IColorFiltered).SetEffectiveColorMatrix(_effectiveMatrix);
		}
	}

	static function SameMatrix(a:NativeArray<Single>, b:NativeArray<Single>):Bool {
		if (a == b) {
			return true;
		}
		if (a == null || b == null || a.Length != b.Length) {
			return false;
		}
		for (i in 0...a.Length) {
			if (a[i] != b[i]) {
				return false;
			}
		}
		return true;
	}

	var _contentCount = 0;
	final _painter:UIPainter;
	var _cursorName:String;
	var _blur = 0.0;
	var _pixelated = false;

	/** Takes the style to paint (the same instance may come back changed) and repaints. */
	public function ApplyStyle(style:UIStyle):Void {
		_painter.Style = style;
		_styleOpacity = style.Opacity;
		Opacity = _styleOpacity * _alpha;
		if (style.Blur != _blur) {
			_blur = style.Blur;
			// CSS blur(n) is a Gaussian of standard deviation n; Avalonia's radius 4n matches html5's
			// blur(n) in the gallery (measured by how far the blurred text spreads).
			if (_blur > 0) {
				var effect = new BlurEffect();
				effect.Radius = _blur * 4;
				Effect = effect;
			} else {
				Effect = null;
			}
		}
		if (style.Pixelated != _pixelated) {
			_pixelated = style.Pixelated;
			RenderOptions.SetBitmapInterpolationMode(_painter, _pixelated ? None : Unspecified);
		}
		if (style.Cursor != _cursorName) {
			_cursorName = style.Cursor;
			if (!_cursorSuppressed && !_overLink) {
				Cursor = UIStyle.CursorFor(style.Cursor);
			}
		}
		_painter.InvalidateVisual();
	}

	public function new() {
		super();
		// Panel.Render is sealed in Avalonia 12, so a painter child underneath everything does the drawing.
		_painter = new UIPainter();
		AddContent(_painter);
	}

	var _cursorSuppressed = false;

	/** The CSS cursor this panel shows; null when it has none or it is disabled. */
	@:property public var CursorName(get, never):String;

	function get_CursorName():String {
		return _cursorSuppressed ? null : _cursorName;
	}

	/** A disabled component drops its cursor (as html5 does) and gets it back when enabled. */
	public function SetCursorSuppressed(suppressed:Bool):Void {
		if (suppressed == _cursorSuppressed) {
			return;
		}
		_cursorSuppressed = suppressed;
		_overLink = false;
		Cursor = suppressed ? null : UIStyle.CursorFor(_cursorName);
	}

	// ---- a hand over a link in this panel's text, as a browser shows one ----

	var _linkHandlers = false;
	var _overLink = false;

	/**
	 * A text in this panel's content has new HTML; from its first link on, the
	 * pointer is watched for whether it is over one.
	 */
	public function LinksChanged():Void {
		if (_linkHandlers || !HasLinks()) {
			return;
		}
		_linkHandlers = true;
		var moved:EventHandler_1<PointerEventArgs> = function(s:Dynamic, e:PointerEventArgs) {
			SetOverLink(OverLink(e));
		};
		AddHandler(InputElement.PointerMovedEvent, moved, RoutingStrategies.Bubble, true);
		var exited:EventHandler_1<PointerEventArgs> = function(s:Dynamic, e:PointerEventArgs) {
			SetOverLink(false);
		};
		AddHandler(InputElement.PointerExitedEvent, exited, RoutingStrategies.Direct, true);
	}

	function HasLinks():Bool {
		var children = Children;
		for (i in 0..._contentCount) {
			var child = children[i];
			if (Std.isOfType(child, UIText) && (cast child : UIText).LinkCount > 0) {
				return true;
			}
		}
		return false;
	}

	function OverLink(e:PointerEventArgs):Bool {
		var children = Children;
		for (i in 0..._contentCount) {
			var child = children[i];
			if (!Std.isOfType(child, UIText)) {
				continue;
			}
			var text:UIText = cast child;
			if (text.LinkCount == 0 || !text.IsVisible) {
				continue;
			}
			var p = e.GetPosition(text);
			if (text.LinkAt(p.X, p.Y) >= 0) {
				return true;
			}
		}
		return false;
	}

	function SetOverLink(over:Bool):Void {
		if (_cursorSuppressed) {
			over = false;
		}
		if (over == _overLink) {
			return;
		}
		_overLink = over;
		Cursor = UIStyle.CursorFor(over ? "pointer" : _cursorName);
	}

	public var Left(default, null):Float = 0;
	public var Top(default, null):Float = 0;
	public var W(default, null):Float = 0;
	public var H(default, null):Float = 0;

	public var ClipEnabled(default, null):Bool = false;
	public var ClipLeft(default, null):Float = 0;
	public var ClipTop(default, null):Float = 0;
	public var ClipWidth(default, null):Float = 0;
	public var ClipHeight(default, null):Float = 0;

	@:property public var ChildCount(get, never):Int;

	function get_ChildCount():Int {
		return Children.Count - _contentCount;
	}

	var _events:EventRouter;

	/** The component's canvas drawing, painted over its style and under its children. */
	public function SetGraphics(graphics:UIGraphics):Void {
		if (_painter.Graphics != null) {
			_painter.Graphics.Changed = null;
		}
		_painter.Graphics = graphics;
		if (graphics != null) {
			var changed:Action = function() {
				_painter.InvalidateVisual();
			};
			graphics.Changed = changed;
		}
		_painter.InvalidateVisual();
	}

	/** Forwards the input kinds in the mask (EventKind flags) to the listener; 0 stops it. */
	public function Listen(kinds:Int, listener:IPanelListener):Void {
		if (_events == null) {
			if (kinds == 0) {
				return;
			}
			_events = new EventRouter(this, false);
		}
		_events.Update(kinds, listener);
	}

	/** Sets position and size; NaN leaves that value as it was. */
	public function SetBounds(left:Float, top:Float, width:Float, height:Float):Void {
		if (!Math.isNaN(left)) {
			Left = left;
		}
		if (!Math.isNaN(top)) {
			Top = top;
		}
		if (!Math.isNaN(width)) {
			W = Math.max(0, width);
		}
		if (!Math.isNaN(height)) {
			H = Math.max(0, height);
		}
		Width = W;
		Height = H;
		_painter.Width = W;
		_painter.Height = H;
		if (!Math.isNaN(_insetTop)) {
			UpdateClip(); // the inset is measured from the edges
		}
		if (_rotation != 0 && (_scaleX != 1 || _scaleY != 1)) {
			UpdateTransform(); // turned about the centre
		}
		Place();
	}

	/**
	 * HaxeUI's clipRect, in this panel's own coordinates: only that rect shows, and the panel
	 * moves by -left/-top so the rect's corner sits at the component's position (scrolling).
	 */
	public function SetClip(enabled:Bool, left:Float, top:Float, width:Float, height:Float):Void {
		ClipEnabled = enabled;
		ClipLeft = enabled ? left : 0;
		ClipTop = enabled ? top : 0;
		ClipWidth = enabled ? width : 0;
		ClipHeight = enabled ? height : 0;
		UpdateClip();
		Place();
	}

	var _insetTop = Math.NaN;
	var _insetRight = 0.0;
	var _insetBottom = 0.0;
	var _insetLeft = 0.0;

	/** CSS clip-path: inset(top right bottom left), within HaxeUI's own clip; NaN clears it. */
	public function SetClipInset(top:Float, right:Float, bottom:Float, left:Float):Void {
		_insetTop = top;
		_insetRight = right;
		_insetBottom = bottom;
		_insetLeft = left;
		UpdateClip();
	}

	/** Whether only part of the panel shows: VisibleRect says which. */
	inline function HasVisibleRect():Bool {
		return ClipEnabled || !Math.isNaN(_insetTop);
	}

	/** The rect that shows: HaxeUI's clip rect and the clip-path inset, either or both. */
	function VisibleRect():Rect {
		var clip = new Rect(ClipLeft, ClipTop, Math.max(0, ClipWidth), Math.max(0, ClipHeight));
		if (Math.isNaN(_insetTop)) {
			return clip;
		}
		var inset = new Rect(_insetLeft, _insetTop, Math.max(0, W - _insetLeft - _insetRight), Math.max(0, H - _insetTop - _insetBottom));
		return ClipEnabled ? clip.Intersect(inset) : inset;
	}

	function UpdateClip():Void {
		Clip = HasVisibleRect() ? new RectangleGeometry(VisibleRect()) : null;
	}

	var _rotation = 0.0;
	var _scaleX = 1.0;
	var _scaleY = 1.0;
	var _styleOpacity = 1.0;
	var _alpha = 1.0;

	/** html5's rotation directive: turned about the panel's centre, in degrees. */
	public function SetRotation(degrees:Float):Void {
		_rotation = Math.isNaN(degrees) ? 0 : degrees;
		UpdateTransform();
	}

	/**
	 * Drawn at a scale about the panel's own top-left, as a display-list backend scales an object
	 * about its origin (haxeui-heaps' h2d scaleX/scaleY). Layout is untouched: HaxeUI still sizes
	 * and places the component unscaled, so its hit box is the unscaled one; a scale is for a
	 * transition, not a resting state. It composes with SetRotation.
	 */
	public function SetScale(scaleX:Float, scaleY:Float):Void {
		if (scaleX == _scaleX && scaleY == _scaleY) {
			return;
		}
		_scaleX = scaleX;
		_scaleY = scaleY;
		UpdateTransform();
	}

	/**
	 * A fade of the owner's own, multiplied into the style's opacity rather than replacing
	 * it (haxeui-heaps' h2d alpha on a component).
	 */
	public function SetAlpha(alpha:Float):Void {
		if (alpha == _alpha) {
			return;
		}
		_alpha = alpha;
		Opacity = _styleOpacity * _alpha;
	}

	function UpdateTransform():Void {
		var scaled = _scaleX != 1 || _scaleY != 1;
		if (!scaled) {
			RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
			RenderTransform = _rotation == 0 ? null : new RotateTransform(_rotation);
			return;
		}
		RenderTransformOrigin = new RelativePoint(0, 0, RelativeUnit.Absolute);
		if (_rotation == 0) {
			RenderTransform = new ScaleTransform(_scaleX, _scaleY);
			return;
		}
		// Both: turned about the unscaled centre, then the whole scaled about the top-left.
		var group = new TransformGroup();
		group.Children.Add(new RotateTransform(_rotation, W * 0.5, H * 0.5));
		group.Children.Add(new ScaleTransform(_scaleX, _scaleY));
		RenderTransform = group;
	}

	public function SetVisible(visible:Bool):Void {
		IsVisible = visible;
	}

	public function InsertChild(child:Control, index:Int):Void {
		Detach(child);
		var count = ChildCount;
		var at = _contentCount + (index < 0 ? 0 : index > count ? count : index);
		Children.Insert(at, child);
		PassColorMatrix(child);
	}

	/**
	 * HaxeUI adds a component elsewhere without removing it first (html5 and heaps move the
	 * node); Avalonia refuses a second parent, so the old one lets go first.
	 */
	static function Detach(child:Control):Void {
		var parent = child.Parent;
		if (Std.isOfType(parent, UIPanel)) {
			(cast parent : UIPanel).RemoveChild(child);
		} else if (Std.isOfType(parent, Panel)) {
			(cast parent : Panel).Children.Remove(child);
		}
	}

	public function RemoveChild(child:Control):Void {
		var at = Children.IndexOf(child);
		if (at < 0) {
			return;
		}
		Children.RemoveAt(at);
		if (at < _contentCount) {
			_contentCount--;
		}
	}

	public function MoveChild(child:Control, index:Int):Void {
		var at = Children.IndexOf(child);
		if (at < _contentCount) {
			return;
		}
		Children.RemoveAt(at);
		InsertChild(child, index);
	}

	/** Index among child panels (the HaxeUI childComponents index), or -1. */
	public function IndexOfChild(child:Control):Int {
		var at = Children.IndexOf(child);
		return at < _contentCount ? -1 : at - _contentCount;
	}

	/** Adds the component's own text, image or input underneath its child panels. */
	public function AddContent(content:Control):Void {
		Detach(content);
		Children.Insert(_contentCount, content);
		_contentCount++;
		PassColorMatrix(content);
		if (Std.isOfType(content, UIText)) {
			LinksChanged();
		}
	}

	public function HitTest(point:Point):Bool {
		if (HasVisibleRect() && !VisibleRect().Contains(point)) {
			return false;
		}
		return point.X >= 0 && point.Y >= 0 && point.X < W && point.Y < H;
	}

	function Place():Void {
		Canvas.SetLeft(this, Left - ClipLeft);
		Canvas.SetTop(this, Top - ClipTop);
	}
}

/** Paints a UIPanel's own style (background, then border) beneath its content and children. */
@:native("HaxeUICs.UIPainter")
@:nativeGen
class UIPainter extends Control implements IColorFiltered {
	public var Style:UIStyle;
	public var Graphics:UIGraphics;

	var _matrix:NativeArray<Single>;

	public function SetEffectiveColorMatrix(matrix:NativeArray<Single>):Void {
		_matrix = matrix;
		InvalidateVisual();
	}

	public function new() {
		super();
		IsHitTestVisible = false;
	}

	override public function Render(context:DrawingContext):Void {
		if (Style != null) {
			Style.PaintMatrix = _matrix;
		}
		RenderStyle(context);
		if (Graphics != null) {
			Graphics.Render(context, _matrix);
		}
	}

	function RenderStyle(context:DrawingContext):Void {
		var s = Style;
		var size = Bounds;
		var width = size.Width;
		var height = size.Height;
		if (s == null || width <= 0 || height <= 0) {
			return;
		}
		var bounds = new Rect(0, 0, width, height);

		var background = s.BackgroundBrush();
		if (s.Shadows.Count > 0) {
			// Shadows hug the background's rounded rect, drawn with it (outside, or inset inside).
			context.DrawRectangle(background, null, new RoundedRect(bounds, s.RadiusTL, s.RadiusTR, s.RadiusBR, s.RadiusBL), s.PaintShadows());
		} else if (background != null) {
			if (s.HasRadius) {
				context.DrawRectangle(background, null, new RoundedRect(bounds, s.RadiusTL, s.RadiusTR, s.RadiusBR, s.RadiusBL), new BoxShadows());
			} else {
				context.FillRectangle(background, bounds, 0);
			}
		}

		if (s.BackgroundImage != null) {
			RenderBackgroundImage(context, s, bounds, UIImage.DeviceScale(this));
		}

		RenderBorder(context, s, bounds);
	}

	static function RenderBackgroundImage(context:DrawingContext, s:UIStyle, bounds:Rect, renderScale:Float):Void {
		// Source rects are in the image's own units; `ratio` takes them to the bitmap's pixels,
		// which for an SVG is drawn at the size it shows (stretched backgrounds larger).
		var picture = s.BackgroundImage;
		var stretch:Float = picture.IsVector && s.Repeat == 0 && !s.HasSlice ? Math.max(bounds.Width / picture.Width, bounds.Height / picture.Height) : 1;
		var k = Math.max(1, Math.min(64, renderScale * stretch));
		var image = ColorMatrix.Filter(picture.BitmapFor(picture.Width * k, picture.Height * k), s.PaintMatrix);
		var ratio = image.PixelSize.Width / picture.Width;
		var source = s.HasClip ? new Rect(s.ClipL, s.ClipT, s.ClipR - s.ClipL, s.ClipB - s.ClipT) : new Rect(0, 0, picture.Width, picture.Height);
		if (source.Width <= 0 || source.Height <= 0) {
			return;
		}
		if (!s.HasRadius) {
			DrawBackgroundImage(context, s, image, ratio, source, bounds);
			return;
		}
		// Within the background's rounded corners, as html5 clips it.
		var corners = context.PushGeometryClip(RoundedPath(bounds, new Vector(s.RadiusTL, s.RadiusTL), new Vector(s.RadiusTR, s.RadiusTR),
			new Vector(s.RadiusBR, s.RadiusBR), new Vector(s.RadiusBL, s.RadiusBL)));
		try {
			DrawBackgroundImage(context, s, image, ratio, source, bounds);
		} catch (e:Exception) {
			corners.Dispose();
			throw e;
		}
		corners.Dispose();
	}

	static function DrawBackgroundImage(context:DrawingContext, s:UIStyle, image:Bitmap, ratio:Float, source:Rect, bounds:Rect):Void {
		if (s.HasSlice) {
			// Source columns/rows around the centre rect; destination keeps the corners' size.
			// With repeat, the edges and centre are tiled at their own size (as heaps does)
			// instead of stretched.
			var sx = [source.X, source.X + s.SliceL, source.X + s.SliceR, source.Right];
			var sy = [source.Y, source.Y + s.SliceT, source.Y + s.SliceB, source.Bottom];
			var dx = [0, s.SliceL, bounds.Width - (source.Width - s.SliceR), bounds.Width];
			var dy = [0, s.SliceT, bounds.Height - (source.Height - s.SliceB), bounds.Height];
			for (row in 0...3) {
				for (col in 0...3) {
					var part = new Rect(sx[col], sy[row], sx[col + 1] - sx[col], sy[row + 1] - sy[row]);
					var into = new Rect(dx[col], dy[row], dx[col + 1] - dx[col], dy[row + 1] - dy[row]);
					if (s.Repeat == 1 && (row == 1 || col == 1)) {
						DrawTiled(context, image, ratio, part, into, col == 1, row == 1, part.Size);
					} else {
						DrawPart(context, image, ratio, part, into);
					}
				}
			}
			return;
		}

		var size = DrawSize(s, source, bounds);
		switch (s.Repeat) {
			case 1:
				DrawTiled(context, image, ratio, source, bounds, true, true, size);
			case 2:
				DrawPart(context, image, ratio, source, new Rect(0, 0, size.Width, size.Height));
			default:
				DrawPart(context, image, ratio, source, bounds);
		}
	}

	/** background-width/-height (px or %), keeping the image's shape for a side not given. */
	static function DrawSize(s:UIStyle, source:Rect, bounds:Rect):Size {
		var w = !Math.isNaN(s.BgWidth) ? s.BgWidth : !Math.isNaN(s.BgWidthPercent) ? bounds.Width * s.BgWidthPercent / 100 : Math.NaN;
		var h = !Math.isNaN(s.BgHeight) ? s.BgHeight : !Math.isNaN(s.BgHeightPercent) ? bounds.Height * s.BgHeightPercent / 100 : Math.NaN;
		if (Math.isNaN(w) && Math.isNaN(h)) {
			return source.Size;
		}
		if (Math.isNaN(w)) {
			w = h * source.Width / source.Height;
		}
		if (Math.isNaN(h)) {
			h = w * source.Height / source.Width;
		}
		return new Size(w, h);
	}

	/** Repeats a source rect across a destination, along x, y or both; stretched along the other. */
	static function DrawTiled(context:DrawingContext, image:Bitmap, ratio:Float, source:Rect, into:Rect, alongX:Bool, alongY:Bool, step:Size):Void {
		if (into.Width <= 0 || into.Height <= 0) {
			return;
		}
		var stepX = alongX ? step.Width : into.Width;
		var stepY = alongY ? step.Height : into.Height;
		if (stepX <= 0 || stepY <= 0) {
			return;
		}
		var clip = context.PushClip(into);
		try {
			var y = into.Y;
			while (y < into.Bottom) {
				var x = into.X;
				while (x < into.Right) {
					DrawPart(context, image, ratio, source, new Rect(x, y, stepX, stepY));
					x += stepX;
				}
				y += stepY;
			}
		} catch (e:Exception) {
			clip.Dispose();
			throw e;
		}
		clip.Dispose();
	}

	static function DrawPart(context:DrawingContext, image:Bitmap, ratio:Float, source:Rect, destination:Rect):Void {
		if (source.Width > 0 && source.Height > 0 && destination.Width > 0 && destination.Height > 0) {
			context.DrawImage(image, new Rect(source.X * ratio, source.Y * ratio, source.Width * ratio, source.Height * ratio), destination);
		}
	}

	static function RenderBorder(context:DrawingContext, s:UIStyle, bounds:Rect):Void {
		if (s.UniformBorder) {
			var size = s.BorderLeft;
			var brush = s.BorderBrush(s.BorderLeftColor);
			if (size <= 0 || brush == null) {
				return;
			}
			// A pen is centred on its path: inset by half its width so the border sits inside.
			var half = size / 2;
			var inner = bounds.Deflate(half);
			context.DrawRectangle(null, s.BorderPen(brush, size),
				new RoundedRect(inner, Math.max(0, s.RadiusTL - half), Math.max(0, s.RadiusTR - half), Math.max(0, s.RadiusBR - half), Math.max(0, s.RadiusBL - half)),
				new BoxShadows());
			return;
		}
		if (s.BorderStyle != 0) {
			// Dashed or dotted sides are stroked along each side's centre line.
			StrokeSide(context, s, s.BorderTopColor, s.BorderTop, new Point(0, s.BorderTop / 2), new Point(bounds.Width, s.BorderTop / 2));
			StrokeSide(context, s, s.BorderRightColor, s.BorderRight, new Point(bounds.Width - s.BorderRight / 2, 0),
				new Point(bounds.Width - s.BorderRight / 2, bounds.Height));
			StrokeSide(context, s, s.BorderBottomColor, s.BorderBottom, new Point(bounds.Width, bounds.Height - s.BorderBottom / 2),
				new Point(0, bounds.Height - s.BorderBottom / 2));
			StrokeSide(context, s, s.BorderLeftColor, s.BorderLeft, new Point(s.BorderLeft / 2, bounds.Height), new Point(s.BorderLeft / 2, 0));
			return;
		}
		if (!s.HasRadius) {
			FillSide(context, s.BorderBrush(s.BorderLeftColor), new Rect(0, 0, s.BorderLeft, bounds.Height));
			FillSide(context, s.BorderBrush(s.BorderRightColor), new Rect(bounds.Width - s.BorderRight, 0, s.BorderRight, bounds.Height));
			FillSide(context, s.BorderBrush(s.BorderTopColor), new Rect(0, 0, bounds.Width, s.BorderTop));
			FillSide(context, s.BorderBrush(s.BorderBottomColor), new Rect(0, bounds.Height - s.BorderBottom, bounds.Width, s.BorderBottom));
			return;
		}
		// Rounded: the border is the ring between the outer rounded rect and the inner one (each
		// corner's radius less the two sides meeting there), and each side's colour fills its share
		// of the ring: the trapezoid from its two outer corners in to its two inner ones, as CSS does.
		var l = s.BorderLeft;
		var t = s.BorderTop;
		var r = s.BorderRight;
		var b = s.BorderBottom;
		var w = bounds.Width;
		var h = bounds.Height;
		var outer = RoundedPath(bounds, new Vector(s.RadiusTL, s.RadiusTL), new Vector(s.RadiusTR, s.RadiusTR), new Vector(s.RadiusBR, s.RadiusBR),
			new Vector(s.RadiusBL, s.RadiusBL));
		var hole = RoundedPath(new Rect(l, t, Math.max(0, w - l - r), Math.max(0, h - t - b)), new Vector(Math.max(0, s.RadiusTL - l), Math.max(0, s.RadiusTL - t)),
			new Vector(Math.max(0, s.RadiusTR - r), Math.max(0, s.RadiusTR - t)), new Vector(Math.max(0, s.RadiusBR - r), Math.max(0, s.RadiusBR - b)),
			new Vector(Math.max(0, s.RadiusBL - l), Math.max(0, s.RadiusBL - b)));
		var ring = new CombinedGeometry(GeometryCombineMode.Exclude, outer, hole);
		FillShare(context, s.BorderBrush(s.BorderTopColor), t, ring, new Point(0, 0), new Point(w, 0), new Point(w - r, t), new Point(l, t));
		FillShare(context, s.BorderBrush(s.BorderRightColor), r, ring, new Point(w, 0), new Point(w, h), new Point(w - r, h - b), new Point(w - r, t));
		FillShare(context, s.BorderBrush(s.BorderBottomColor), b, ring, new Point(w, h), new Point(0, h), new Point(l, h - b), new Point(w - r, h - b));
		FillShare(context, s.BorderBrush(s.BorderLeftColor), l, ring, new Point(0, h), new Point(0, 0), new Point(l, t), new Point(l, h - b));
	}

	static function StrokeSide(context:DrawingContext, s:UIStyle, color:UInt, size:Float, from:Point, to:Point):Void {
		var brush = s.BorderBrush(color);
		if (brush != null && size > 0) {
			context.DrawLine(s.BorderPen(brush, size), from, to);
		}
	}

	static function FillSide(context:DrawingContext, brush:IBrush, side:Rect):Void {
		if (brush != null && side.Width > 0 && side.Height > 0) {
			context.FillRectangle(brush, side, 0);
		}
	}

	/** Fills one side's share of a rounded border ring: the ring, clipped to its trapezoid. */
	static function FillShare(context:DrawingContext, brush:IBrush, size:Float, ring:Geometry, a:Point, b:Point, c:Point, d:Point):Void {
		if (brush == null || size <= 0) {
			return;
		}
		var share = new StreamGeometry();
		var g = share.Open();
		g.BeginFigure(a, true);
		g.LineTo(b, true);
		g.LineTo(c, true);
		g.LineTo(d, true);
		g.EndFigure(true);
		g.Dispose();
		var clip = context.PushGeometryClip(share);
		try {
			context.DrawGeometry(brush, null, ring);
		} catch (e:Exception) {
			clip.Dispose();
			throw e;
		}
		clip.Dispose();
	}

	/** A rect with each corner rounded by its own (x, y) radii. */
	static function RoundedPath(r:Rect, tl:Vector, tr:Vector, br:Vector, bl:Vector):Geometry {
		var path = new StreamGeometry();
		var g = path.Open();
		g.BeginFigure(new Point(r.Left + tl.X, r.Top), true);
		g.LineTo(new Point(r.Right - tr.X, r.Top), true);
		if (tr.X > 0 && tr.Y > 0) {
			g.ArcTo(new Point(r.Right, r.Top + tr.Y), new Size(tr.X, tr.Y), 0, false, SweepDirection.Clockwise, true);
		}
		g.LineTo(new Point(r.Right, r.Bottom - br.Y), true);
		if (br.X > 0 && br.Y > 0) {
			g.ArcTo(new Point(r.Right - br.X, r.Bottom), new Size(br.X, br.Y), 0, false, SweepDirection.Clockwise, true);
		}
		g.LineTo(new Point(r.Left + bl.X, r.Bottom), true);
		if (bl.X > 0 && bl.Y > 0) {
			g.ArcTo(new Point(r.Left, r.Bottom - bl.Y), new Size(bl.X, bl.Y), 0, false, SweepDirection.Clockwise, true);
		}
		g.LineTo(new Point(r.Left, r.Top + tl.Y), true);
		if (tl.X > 0 && tl.Y > 0) {
			g.ArcTo(new Point(r.Left + tl.X, r.Top), new Size(tl.X, tl.Y), 0, false, SweepDirection.Clockwise, true);
		}
		g.EndFigure(true);
		g.Dispose();
		return path;
	}
}
