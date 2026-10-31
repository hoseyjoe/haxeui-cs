package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.Ref;
import cs.system.IDisposable;
import cs.types.UInt8;

/** Externs for SkiaSharp and Avalonia's lease of its canvas, written by hand as hxc binds them. */
@:native("SkiaSharp.SKColorType")
extern enum SKColorType {
	Rgba8888;
}

@:native("SkiaSharp.SKAlphaType")
extern enum SKAlphaType {
	Unpremul;
}

@:native("SkiaSharp.SKFilterMode")
extern enum SKFilterMode {
	Linear;
}

@:native("SkiaSharp.SKMipmapMode")
extern enum SKMipmapMode {
	None;
}

@:native("SkiaSharp.SKClipOperation")
extern enum SKClipOperation {
	Intersect;
}

@:native("SkiaSharp.SKBlendMode")
extern enum SKBlendMode {
	DstIn;
}

@:native("SkiaSharp.SKImageInfo")
@:struct
extern class SKImageInfo {
	@:overload function new(width:Int, height:Int, colorType:SKColorType, alphaType:SKAlphaType);
}

@:native("SkiaSharp.SKRect")
@:struct
extern class SKRect {
	function new(left:Single, top:Single, right:Single, bottom:Single);
}

@:native("SkiaSharp.SKMatrix")
@:struct
extern class SKMatrix {
	@:overload function new(scaleX:Single, skewX:Single, transX:Single, skewY:Single, scaleY:Single, transY:Single, persp0:Single, persp1:Single,
		persp2:Single);
}

@:native("SkiaSharp.SKColor")
@:struct
extern class SKColor {
	@:overload function new(red:UInt8, green:UInt8, blue:UInt8, alpha:UInt8);
}

@:native("SkiaSharp.SKSamplingOptions")
@:struct
extern class SKSamplingOptions {
	@:overload function new(filter:SKFilterMode, mipmap:SKMipmapMode);
}

@:native("SkiaSharp.SKImage")
extern class SKImage {
	@:overload static function FromPixelCopy(info:SKImageInfo, pixels:NativeArray<UInt8>):SKImage;
}

@:native("SkiaSharp.SKColorFilter")
extern class SKColorFilter {
	@:overload static function CreateColorMatrix(matrix:NativeArray<Single>):SKColorFilter;
}

@:native("SkiaSharp.SKPaint")
extern class SKPaint {
	@:overload function new();
	var Color:SKColor;
	var ColorFilter:SKColorFilter;
	var BlendMode:SKBlendMode;
	function Clone():SKPaint;
	function Dispose():Void;
}

@:native("SkiaSharp.SKCanvas")
extern class SKCanvas {
	function Save():Int;
	@:overload function SaveLayer(limit:SKRect, paint:SKPaint):Int;
	function RestoreToCount(count:Int):Void;
	@:overload function Concat(m:Ref<SKMatrix>):Void;
	function ClipRect(rect:SKRect, operation:SKClipOperation, antialias:Bool):Void;
	@:overload function DrawImage(image:SKImage, dest:SKRect, sampling:SKSamplingOptions, paint:SKPaint):Void;
}

@:native("Avalonia.Skia.ISkiaSharpApiLease")
extern interface ISkiaSharpApiLease extends IDisposable {
	var SkCanvas(default, never):SKCanvas;
}

@:native("Avalonia.Skia.ISkiaSharpApiLeaseFeature")
extern interface ISkiaSharpApiLeaseFeature {
	function Lease():ISkiaSharpApiLease;
}
