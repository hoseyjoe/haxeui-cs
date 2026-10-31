package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.system.IDisposable;
import cs.system.IntPtr;
import cs.system.Nullable_1;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Net;

/** Externs for `Avalonia.Media` and bitmaps, written by hand as hxc binds them. */
@:native("Avalonia.Media.Color")
@:struct
extern class Color {
	static function FromUInt32(value:UInt):Color;
	function ToUInt32():UInt;
}

@:native("Avalonia.Media.IBrush")
extern interface IBrush {
	var Opacity(default, never):Float;
}

@:native("Avalonia.Media.ISolidColorBrush")
extern interface ISolidColorBrush extends IBrush {
	var Color(default, never):Color;
}

@:native("Avalonia.Media.SolidColorBrush")
extern class SolidColorBrush implements ISolidColorBrush {
	@:overload function new(color:Color, opacity:Float);
	var Color(default, never):Color;
	var Opacity(default, never):Float;
}

@:native("Avalonia.Media.IGradientStop")
extern interface IGradientStop {
	var Color(default, never):Color;
	var Offset(default, never):Float;
}

@:native("Avalonia.Media.GradientStop")
extern class GradientStop {
	@:overload function new(color:Color, offset:Float);
}

@:native("Avalonia.Media.GradientStops")
extern class GradientStops {
	function new();
	function Add(item:GradientStop):Void;
}

@:native("Avalonia.Media.IGradientBrush")
extern interface IGradientBrush extends IBrush {
	var GradientStops(default, never):IReadOnlyList<IGradientStop>;
}

@:native("Avalonia.Media.ILinearGradientBrush")
extern interface ILinearGradientBrush extends IGradientBrush {
	var StartPoint(default, never):RelativePoint;
	var EndPoint(default, never):RelativePoint;
}

@:native("Avalonia.Media.LinearGradientBrush")
extern class LinearGradientBrush implements IBrush {
	function new();
	var StartPoint:RelativePoint;
	var EndPoint:RelativePoint;
	var GradientStops:GradientStops;
	var Opacity:Float;
}

@:native("Avalonia.Platform.AlphaFormat")
extern enum AlphaFormat {
	Premul;
	Unpremul;
	Opaque;
}

@:native("Avalonia.Platform.PixelFormat")
@:struct
extern class PixelFormat {
	static var Bgra8888(default, never):PixelFormat;
}

@:native("Avalonia.Platform.ILockedFramebuffer")
extern interface ILockedFramebuffer extends IDisposable {
	var Address(default, never):IntPtr;
	var RowBytes(default, never):Int;
}

@:native("Avalonia.Media.Imaging.Bitmap")
extern class Bitmap {
	var PixelSize(default, never):PixelSize;
	var Dpi(default, never):Vector;
	@:overload function CopyPixels(buffer:ILockedFramebuffer):Void;
}

@:native("Avalonia.Media.Imaging.WriteableBitmap")
extern class WriteableBitmap extends Bitmap {
	@:overload function new(size:PixelSize, dpi:Vector, format:Nullable_1<PixelFormat>, alphaFormat:Nullable_1<AlphaFormat>);
	function Lock():ILockedFramebuffer;
}

@:native("System.Runtime.InteropServices.Marshal")
extern class Marshal {
	@:overload static function Copy(source:IntPtr, destination:NativeArray<UInt8>, startIndex:Int, length:Int):Void;
	@:overload static function Copy(source:NativeArray<UInt8>, startIndex:Int, destination:IntPtr, length:Int):Void;
}

@:native("System.Runtime.CompilerServices.ConditionalWeakTable`2")
extern class ConditionalWeakTable<K, V> {
	function new();
	function GetOrCreateValue(key:K):V;
	function Remove(key:K):Bool;
}
