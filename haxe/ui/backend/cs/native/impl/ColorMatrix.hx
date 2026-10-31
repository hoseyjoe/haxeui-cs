package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Nullable_1;
import cs.types.UInt8;
import haxe.ds.StringMap;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;

/** A bitmap's filtered copies by matrix: the value of ColorMatrix's weak table, which makes one itself. */
@:native("HaxeUICs.FilteredCopies")
@:nativeGen
class FilteredCopies {
	public final Copies = new StringMap<Bitmap>();

	public function new() {}
}

/** Something painted under a colour-filtered panel: it maps its own colours and bitmaps. */
@:native("HaxeUICs.IColorFiltered")
@:nativeGen
interface IColorFiltered {
	/** `matrix`: the effective matrix from every filtered ancestor, or null for none. */
	function SetEffectiveColorMatrix(matrix:NativeArray<Single>):Void;
}

/**
 * CSS colour filters (grayscale, tint, brightness...) as 4x5 colour matrices, row-major as SVG's
 * feColorMatrix: R' = m0 R + m1 G + m2 B + m3 A + m4, with channels and offsets in 0..1.
 * Avalonia 12 has no colour-matrix effect for a subtree, so each painted thing under a filtered
 * panel maps its own colours and pixels through the effective matrix at paint time.
 */
@:native("HaxeUICs.ColorMatrix")
@:nativeGen
class ColorMatrix {
	@:overload
	public static function Apply(m:NativeArray<Single>, argb:UInt):UInt {
		if (m == null) {
			return argb;
		}
		var a:Float = ((argb >> 24) & 0xFF) / 255.0;
		var r:Float = ((argb >> 16) & 0xFF) / 255.0;
		var g:Float = ((argb >> 8) & 0xFF) / 255.0;
		var b:Float = (argb & 0xFF) / 255.0;
		return Pack(m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19], m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4],
			m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9], m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]);
	}

	@:overload
	public static function Apply(m:NativeArray<Single>, color:Color):Color {
		return m == null ? color : Color.FromUInt32(Apply(m, color.ToUInt32()));
	}

	/** The matrix that applies `inner` first, then `outer`; either may be null. */
	public static function Compose(outer:NativeArray<Single>, inner:NativeArray<Single>):NativeArray<Single> {
		if (outer == null) {
			return inner;
		}
		if (inner == null) {
			return outer;
		}
		var result = new NativeArray<Single>(20);
		for (row in 0...4) {
			for (col in 0...5) {
				var sum:Float = col == 4 ? outer[row * 5 + 4] : 0; // the outer offset, applied after
				for (k in 0...4) {
					sum += outer[row * 5 + k] * inner[k * 5 + col];
				}
				result[row * 5 + col] = sum;
			}
		}
		return result;
	}

	/** A brush with its colours mapped; the same brush when there is no matrix. */
	public static function Brush(brush:IBrush, m:NativeArray<Single>):IBrush {
		if (m == null || brush == null) {
			return brush;
		}
		if (Std.isOfType(brush, ISolidColorBrush)) {
			var solid:ISolidColorBrush = cast brush;
			return new SolidColorBrush(Apply(m, solid.Color), solid.Opacity);
		}
		if (Std.isOfType(brush, ILinearGradientBrush)) {
			var linear:ILinearGradientBrush = cast brush;
			var stops = new GradientStops();
			var from = linear.GradientStops;
			var all:IReadOnlyCollection<IGradientStop> = from; // Count is on the collection, as hxc binds it
			for (i in 0...all.Count) {
				var stop:IGradientStop = from[i];
				stops.Add(new GradientStop(Apply(m, stop.Color), stop.Offset));
			}
			var result = new LinearGradientBrush();
			result.StartPoint = linear.StartPoint;
			result.EndPoint = linear.EndPoint;
			result.GradientStops = stops;
			result.Opacity = linear.Opacity;
			return result;
		}
		return brush;
	}

	static final _filtered = new ConditionalWeakTable<Bitmap, FilteredCopies>();

	/** Forgets the filtered copies of a bitmap whose pixels were changed in place. */
	public static function Forget(source:Bitmap):Void {
		if (source != null) {
			_filtered.Remove(source);
		}
	}

	/** The bitmap with every pixel mapped (cached per bitmap and matrix); itself with no matrix. */
	public static function Filter(source:Bitmap, m:NativeArray<Single>):Bitmap {
		if (m == null || source == null) {
			return source;
		}
		var key = new StringBuf();
		for (i in 0...m.Length) {
			key.add(m[i]);
			key.add(",");
		}
		var cacheKey = key.toString();
		var cache = _filtered.GetOrCreateValue(source);
		if (cache.Copies.exists(cacheKey)) {
			return cache.Copies.get(cacheKey);
		}
		var size = source.PixelSize;
		var result = new WriteableBitmap(size, source.Dpi, new Nullable_1(PixelFormat.Bgra8888), new Nullable_1(AlphaFormat.Unpremul));
		var buffer = result.Lock();
		Scope.run(buffer, () -> {
			source.CopyPixels(buffer); // converted to the buffer's own format: straight BGRA
			var rowBytes = buffer.RowBytes;
			var bytes = new NativeArray<UInt8>(rowBytes * size.Height);
			Marshal.Copy(buffer.Address, bytes, 0, bytes.Length);
			for (y in 0...size.Height) {
				for (x in 0...size.Width) {
					var i = y * rowBytes + x * 4;
					var argb:UInt = ((bytes[i + 3] : Int) << 24 : UInt) | ((bytes[i + 2] : Int) << 16 : UInt) | ((bytes[i + 1] : Int) << 8 : UInt)
						| ((bytes[i] : Int) : UInt);
					argb = Apply(m, argb);
					bytes[i] = cast(argb & 0xFF);
					bytes[i + 1] = cast((argb >> 8) & 0xFF);
					bytes[i + 2] = cast((argb >> 16) & 0xFF);
					bytes[i + 3] = cast(argb >> 24);
				}
			}
			Marshal.Copy(bytes, 0, buffer.Address, bytes.Length);
		});
		cache.Copies.set(cacheKey, result);
		return result;
	}

	static function Pack(a:Float, r:Float, g:Float, b:Float):UInt {
		return (Channel(a) << 24) | (Channel(r) << 16) | (Channel(g) << 8) | Channel(b);
	}

	static function Channel(v:Float):UInt {
		var clamped = v < 0 ? 0.0 : v > 1 ? 1.0 : v;
		return Std.int(cs.system.Math.Round(clamped * 255));
	}
}
