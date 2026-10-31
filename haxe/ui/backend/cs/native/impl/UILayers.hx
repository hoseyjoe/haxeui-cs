package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Action;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Skia;

/** A layer as it stands now: the UI thread's. */
@:native("HaxeUICs.UILayersLayer")
@:nativeGen
class Layer {
	public final IsGroup:Bool;
	public var Transform = Matrix.Identity;
	public var Opacity = 1.0;
	public var Visible = true;
	public var Image:SKImage; // a bitmap's pixels; a group's mask. Never changed once made: the render thread may be drawing it
	public var Dest:Rect; // where the pixels go, in the group's units
	public final Children = new Array<Int>();

	public function new(isGroup:Bool) {
		IsGroup = isGroup;
	}
}

/**
 * Retained layers drawn over a canvas's own drawing: a tree of groups, each with a matrix, an
 * opacity and an optional mask, holding bitmaps placed in their group's units. For content that
 * moves every frame while its pixels mostly don't, such as an animated SVG's layers: placing a
 * group again costs a repaint, not a raster. A group that fades is composited as one image.
 *
 * Drawn straight through Skia (offscreen layers, as heaps' filters are): Avalonia's own opacity
 * mask maps an image brush wrongly once the window has a render scaling (150%), and its
 * PushOpacity fades each drawing on its own, so a group's overlaps would show.
 */
@:native("HaxeUICs.UILayers")
@:nativeGen
class UILayers {
	final _layers = new Array<Layer>();
	final _roots = new Array<Int>();

	/** Called when the layers change, so their owner repaints. */
	public var Changed:Action;

	public var Count(get, never):Int;

	function get_Count():Int {
		return _layers.length;
	}

	public function new() {}

	/** A new group inside `parent` (-1: at the top), drawn above what is already there. */
	public function AddGroup(parent:Int):Int {
		return Add(parent, true);
	}

	/** A new bitmap inside `parent` (-1: at the top), empty until SetPixels. */
	public function AddBitmap(parent:Int):Int {
		return Add(parent, false);
	}

	function Add(parent:Int, group:Bool):Int {
		var siblings = parent >= 0 && parent < _layers.length && _layers[parent].IsGroup ? _layers[parent].Children : _roots;
		_layers.push(new Layer(group));
		siblings.push(_layers.length - 1);
		return _layers.length - 1;
	}

	/** Places a layer in its group: x' = a·x + c·y + e, y' = b·x + d·y + f, as an SVG matrix(a b c d e f). */
	public function SetMatrix(layer:Int, a:Float, b:Float, c:Float, d:Float, e:Float, f:Float):Void {
		if (!Has(layer)) {
			return;
		}
		var m = new Matrix(a, b, c, d, e, f);
		if (_layers[layer].Transform.Equals(m)) {
			return;
		}
		_layers[layer].Transform = m;
		Notify();
	}

	public function SetOpacity(layer:Int, opacity:Float):Void {
		if (!Has(layer)) {
			return;
		}
		var clamped = opacity < 0 ? 0.0 : opacity > 1 ? 1.0 : opacity;
		if (_layers[layer].Opacity == clamped) {
			return;
		}
		_layers[layer].Opacity = clamped;
		Notify();
	}

	public function SetVisible(layer:Int, visible:Bool):Void {
		if (!Has(layer) || _layers[layer].Visible == visible) {
			return;
		}
		_layers[layer].Visible = visible;
		Notify();
	}

	/**
	 * A bitmap's pixels, or a group's mask (its alpha; nothing of the group shows outside it):
	 * RGBA bytes, straight alpha, width × height, drawn into x, y, w × h of the group's units.
	 * Null or empty pixels draw nothing (and remove a group's mask).
	 */
	public function SetPixels(layer:Int, rgba:NativeArray<UInt8>, width:Int, height:Int, x:Float, y:Float, w:Float, h:Float):Void {
		if (!Has(layer)) {
			return;
		}
		var l = _layers[layer];
		l.Image = null;
		if (rgba != null && width > 0 && height > 0 && rgba.Length >= width * height * 4) {
			var size = width * height * 4;
			var exact = rgba;
			if (rgba.Length > size) {
				exact = new NativeArray<UInt8>(size);
				cs.system.Array.Copy(cast rgba, 0, cast exact, 0, size);
			}
			var info = new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Unpremul);
			l.Image = SKImage.FromPixelCopy(info, exact);
			l.Dest = new Rect(x, y, w, h);
		}
		Notify();
	}

	public function Clear():Void {
		_layers.resize(0);
		_roots.resize(0);
		Notify();
	}

	function Has(layer:Int):Bool {
		return layer >= 0 && layer < _layers.length;
	}

	function Notify():Void {
		if (Changed != null) {
			Changed.Invoke();
		}
	}

	/** `matrix`: the colour filter in force (null for none): bitmaps go through it; masks don't. */
	public function Render(context:DrawingContext, matrix:NativeArray<Single>):Void {
		var roots = Snapshots(_roots);
		if (roots != null) {
			context.Custom(new UILayersDraw(roots, Covering(roots), matrix));
		}
	}

	/** What the render thread draws for these layers, fixed now; null for nothing to draw. */
	function Snapshots(layers:Array<Int>):NativeArray<UILayersNode> {
		var nodes = new Array<UILayersNode>();
		for (i in layers) {
			var node = Snapshot(i);
			if (node != null) {
				nodes.push(node);
			}
		}
		if (nodes.length == 0) {
			return null;
		}
		var result = new NativeArray<UILayersNode>(nodes.length);
		for (i in 0...nodes.length) {
			result[i] = nodes[i];
		}
		return result;
	}

	function Covering(nodes:NativeArray<UILayersNode>):Rect {
		var all = nodes[0].Covers;
		for (i in 1...nodes.Length) {
			all = all.Union(nodes[i].Covers);
		}
		return all;
	}

	/** What the render thread draws for layer `i`; null for nothing to draw. */
	function Snapshot(i:Int):UILayersNode {
		var l = _layers[i];
		if (!l.Visible || l.Opacity <= 0) {
			return null;
		}
		var node = new UILayersNode();
		node.Transform = l.Transform;
		node.Opacity = l.Opacity;
		var own:Rect;
		if (!l.IsGroup) {
			if (l.Image == null) {
				return null;
			}
			node.Image = l.Image;
			node.Dest = l.Dest;
			own = l.Dest;
		} else {
			var children = Snapshots(l.Children);
			if (children == null) {
				return null;
			}
			node.Children = children;
			own = Covering(children);
			if (l.Image != null) {
				node.Mask = l.Image;
				node.Dest = l.Dest;
				own = own.Intersect(l.Dest);
			}
			node.Bounds = own;
		}
		node.Covers = own.TransformToAABB(l.Transform);
		return node;
	}
}

@:native("HaxeUICs.UILayersNode")
@:nativeGen
class UILayersNode {
	public var Transform:Matrix;
	public var Opacity:Single;
	public var Image:SKImage; // a bitmap
	public var Mask:SKImage; // a group's
	public var Dest:Rect;
	public var Bounds:Rect; // a group's, in its own units
	public var Covers:Rect; // what it covers in its parent's units, after its matrix
	public var Children:NativeArray<UILayersNode>;

	public function new() {}
}

/**
 * One paint of the layers, run on the render thread over a snapshot of them. No closures, Dynamic
 * or Haxe collections below: nothing here may touch what the UI thread is using.
 */
@:native("HaxeUICs.UILayersDraw")
@:nativeGen
class UILayersDraw implements ICustomDrawOperation {
	static final Smooth = new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.None);

	final _roots:NativeArray<UILayersNode>;
	final _bounds:Rect;
	final _colorMatrix:NativeArray<Single>;

	public function new(roots:NativeArray<UILayersNode>, bounds:Rect, colorMatrix:NativeArray<Single>) {
		_roots = roots;
		_bounds = bounds;
		_colorMatrix = colorMatrix;
	}

	@:property public var Bounds(get, never):Rect;

	function get_Bounds():Rect {
		return _bounds;
	}

	public function HitTest(p:Point):Bool {
		return false;
	}

	public function Equals(other:ICustomDrawOperation):Bool {
		return false; // every paint is a new one
	}

	public function Dispose():Void {}

	public function Render(context:ImmediateDrawingContext):Void {
		var feature:ISkiaSharpApiLeaseFeature = cast context.TryGetFeature(cs.Lib.toNativeType(ISkiaSharpApiLeaseFeature));
		if (feature == null) {
			return;
		}
		var lease = feature.Lease();
		var paint:SKPaint = null;
		try {
			var canvas = lease.SkCanvas;
			paint = new SKPaint();
			if (_colorMatrix != null) {
				paint.ColorFilter = SKColorFilter.CreateColorMatrix(_colorMatrix);
			}
			for (i in 0..._roots.Length) {
				Paint(canvas, _roots[i], paint);
			}
		} catch (e:cs.system.Exception) {
			if (paint != null) {
				paint.Dispose();
			}
			lease.Dispose();
			throw e;
		}
		paint.Dispose();
		lease.Dispose();
	}

	function Paint(canvas:SKCanvas, node:UILayersNode, paint:SKPaint):Void {
		var saved = canvas.Save();
		var m = node.Transform;
		var sk = new SKMatrix(m.M11, m.M21, m.M31, m.M12, m.M22, m.M32, 0, 0, 1);
		canvas.Concat(sk);
		if (node.Children == null) {
			if (node.Opacity < 1) {
				var faded = paint.Clone();
				faded.Color = Faded(node.Opacity);
				DrawDisposing(canvas, node.Image, Sk(node.Dest), faded);
			} else {
				canvas.DrawImage(node.Image, Sk(node.Dest), Smooth, paint);
			}
		} else {
			var bounds = Sk(node.Bounds);
			if (node.Opacity < 1) {
				var fade = new SKPaint();
				fade.Color = Faded(node.Opacity);
				canvas.SaveLayer(bounds, fade); // the group drawn as one image, then faded
				fade.Dispose();
			}
			if (node.Mask != null) {
				canvas.ClipRect(Sk(node.Dest), SKClipOperation.Intersect, false);
				canvas.SaveLayer(bounds, null);
			}
			for (i in 0...node.Children.Length) {
				Paint(canvas, node.Children[i], paint);
			}
			if (node.Mask != null) {
				var keep = new SKPaint();
				keep.BlendMode = SKBlendMode.DstIn;
				DrawDisposing(canvas, node.Mask, Sk(node.Dest), keep);
			}
		}
		canvas.RestoreToCount(saved);
	}

	static function DrawDisposing(canvas:SKCanvas, image:SKImage, dest:SKRect, paint:SKPaint):Void {
		try {
			canvas.DrawImage(image, dest, Smooth, paint);
		} catch (e:cs.system.Exception) {
			paint.Dispose();
			throw e;
		}
		paint.Dispose();
	}

	static function Faded(opacity:Single):SKColor {
		return new SKColor(255, 255, 255, cast Std.int(cs.system.Math.Round(opacity * 255.0)));
	}

	static function Sk(r:Rect):SKRect {
		return new SKRect(r.Left, r.Top, r.Right, r.Bottom);
	}
}
