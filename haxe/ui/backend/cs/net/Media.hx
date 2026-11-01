package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.Out;
import cs.system.IDisposable;
import cs.system.IEquatable_1;
import cs.system.IntPtr;
import cs.system.Nullable_1;
import cs.system.Uri;
import cs.system.collections.generic.IEnumerable_1;
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

@:native("Avalonia.Media.FontFamily")
extern class FontFamily {
	@:overload function new(name:String);
	static var Default(default, never):FontFamily;
}

@:native("Avalonia.Media.GlyphTypeface")
extern class GlyphTypeface {
	var FamilyName(default, never):String;
}

@:native("Avalonia.Media.Fonts.IFontCollection")
extern interface IFontCollection {}

@:native("Avalonia.Media.Fonts.FontCollectionBase")
extern class FontCollectionBase implements IFontCollection {
	private function new();
	var Key(get, never):Uri;
	function get_Key():Uri;
	@:overload function TryAddGlyphTypeface(stream:Stream, typeface:Out<GlyphTypeface>):Bool;
}

@:native("Avalonia.Media.FontManager")
extern class FontManager {
	static var Current(default, never):FontManager;
	function AddFontCollection(collection:IFontCollection):Void;
}

@:native("Avalonia.Media.TextDecoration")
extern class TextDecoration {}

@:native("Avalonia.Collections.AvaloniaList`1")
extern class AvaloniaList<T> implements ArrayAccess<T> {
	var Count(default, never):Int;
	function IndexOf(item:T):Int;
	function Insert(index:Int, item:T):Void;
	function Remove(item:T):Bool;
	function RemoveAt(index:Int):Void;
	function AddRange(items:IEnumerable_1<T>):Void;
	function Add(item:T):Void;
}

@:native("Avalonia.Media.TextDecorationCollection")
extern class TextDecorationCollection extends AvaloniaList<TextDecoration> {
	function new();
}

@:native("Avalonia.Media.TextDecorations")
extern class TextDecorations {
	static var Underline(default, never):TextDecorationCollection;
	static var Strikethrough(default, never):TextDecorationCollection;
}

@:native("Avalonia.Media.FontStyle")
extern enum FontStyle {
	Normal;
	Italic;
	Oblique;
}

@:native("Avalonia.Media.FontWeight")
extern enum FontWeight {
	Normal;
	Bold;
}

@:native("Avalonia.Media.TextAlignment")
extern enum TextAlignment {
	Center;
	Right;
	Justify;
	Left;
}

@:native("Avalonia.Media.TextWrapping")
extern enum TextWrapping {
	NoWrap;
	Wrap;
}

@:native("Avalonia.Media.Brushes")
extern class Brushes {
	static var Transparent(default, never):IBrush;
}

@:native("Avalonia.Media.IEffect")
extern interface IEffect {}

@:native("Avalonia.Media.DropShadowEffect")
extern class DropShadowEffect implements IEffect {
	function new();
	var OffsetX:Float;
	var OffsetY:Float;
	var BlurRadius:Float;
	var Color:Color;
	var Opacity:Float;
}

@:native("Avalonia.Media.IDashStyle")
extern interface IDashStyle {}

@:native("Avalonia.Media.DashStyle")
extern class DashStyle implements IDashStyle {
	@:overload function new(dashes:IEnumerable_1<Float>, offset:Float);
}

@:native("Avalonia.Media.BoxShadow")
@:struct
extern class BoxShadow {
	function new();
	var OffsetX:Float;
	var OffsetY:Float;
	var Blur:Float;
	var Spread:Float;
	var Color:Color;
	var IsInset:Bool;
}

@:native("Avalonia.Media.BoxShadows")
@:struct
extern class BoxShadows {
	var Count(default, never):Int;
	@:overload function new();
	@:overload function new(shadow:BoxShadow);
	@:overload function new(shadow:BoxShadow, rest:NativeArray<BoxShadow>);
}

@:native("Avalonia.Media.PenLineCap")
extern enum PenLineCap {
	Flat;
	Round;
}

@:native("Avalonia.Media.PenLineJoin")
extern enum PenLineJoin {
	Miter;
}

@:native("Avalonia.Media.IPen")
extern interface IPen {}

@:native("Avalonia.Media.Pen")
extern class Pen implements IPen {
	@:overload function new(brush:IBrush, thickness:Float, dashStyle:IDashStyle, lineCap:PenLineCap, lineJoin:PenLineJoin, miterLimit:Float);
	var Thickness(default, never):Float;
}

@:native("Avalonia.Media.FontStretch")
extern enum FontStretch {
	Normal;
}

@:native("Avalonia.Media.FlowDirection")
extern enum FlowDirection {
	LeftToRight;
}

@:native("Avalonia.Media.TextTrimming")
extern class TextTrimming {}

@:native("Avalonia.Media.FontFeatureCollection")
extern class FontFeatureCollection {}

@:native("Avalonia.Media.TextFormatting.TextRunProperties")
extern class TextRunProperties {}

@:native("Avalonia.Utilities.ValueSpan`1")
@:struct
extern class ValueSpan<T> {}

@:native("Avalonia.Media.Typeface")
@:struct
extern class Typeface {
	@:overload function new(family:FontFamily, style:FontStyle, weight:FontWeight, stretch:FontStretch);
}

@:native("Avalonia.Media.TextFormatting.TextLine")
extern class TextLine {
	var Start(default, never):Float;
	var Width(default, never):Float;
	var Baseline(default, never):Float;
	var Height(default, never):Float;
}

@:native("Avalonia.Media.TextFormatting.TextLayout")
extern class TextLayout implements IDisposable {
	@:overload function new(text:String, typeface:Typeface, fontSize:Float, foreground:IBrush, textAlignment:TextAlignment, textWrapping:TextWrapping,
		textTrimming:TextTrimming, textDecorations:TextDecorationCollection, flowDirection:FlowDirection, maxWidth:Float, maxHeight:Float, lineHeight:Float,
		letterSpacing:Float, maxLines:Int, fontFeatures:FontFeatureCollection, textStyleOverrides:IReadOnlyList<ValueSpan<TextRunProperties>>);
	var Height(default, never):Float;
	function HitTestTextRange(start:Int, length:Int):IEnumerable_1<Rect>;
	function Dispose():Void;
	var TextLines(default, never):IReadOnlyList<TextLine>;
}

@:native("Avalonia.Media.DrawingContext.PushedState")
@:struct
extern class PushedState {
	function Dispose():Void;
}

@:native("Avalonia.Media.Geometry")
extern class Geometry {}

@:native("Avalonia.Media.RectangleGeometry")
extern class RectangleGeometry extends Geometry {
	@:overload function new(rect:Rect);
}

@:native("Avalonia.Media.EllipseGeometry")
extern class EllipseGeometry extends Geometry {
	@:overload function new(rect:Rect);
}

@:native("Avalonia.Media.SweepDirection")
extern enum SweepDirection {
	CounterClockwise;
	Clockwise;
}

@:native("Avalonia.Media.StreamGeometryContext")
extern class StreamGeometryContext {
	function BeginFigure(startPoint:Point, isFilled:Bool):Void;
	function LineTo(point:Point, isStroked:Bool):Void;
	function ArcTo(point:Point, size:Size, rotationAngle:Float, isLargeArc:Bool, sweepDirection:SweepDirection, isStroked:Bool):Void;
	function EndFigure(isClosed:Bool):Void;
	function Dispose():Void;
}

@:native("Avalonia.Media.StreamGeometry")
extern class StreamGeometry extends Geometry {
	function new();
	function Open():StreamGeometryContext;
}

@:native("Avalonia.Media.GeometryCombineMode")
extern enum GeometryCombineMode {
	Union;
	Intersect;
	Xor;
	Exclude;
}

@:native("Avalonia.Media.CombinedGeometry")
extern class CombinedGeometry extends Geometry {
	@:overload function new(combineMode:GeometryCombineMode, geometry1:Geometry, geometry2:Geometry);
}

@:native("Avalonia.Media.ITransform")
extern interface ITransform {}

@:native("Avalonia.Media.Transform")
extern class Transform implements ITransform {}

@:native("Avalonia.Media.RotateTransform")
extern class RotateTransform extends Transform {
	@:overload function new(angle:Float);
	@:overload function new(angle:Float, centerX:Float, centerY:Float);
}

@:native("Avalonia.Media.ScaleTransform")
extern class ScaleTransform extends Transform {
	@:overload function new(scaleX:Float, scaleY:Float);
}

@:native("Avalonia.Media.Transforms")
extern class Transforms extends AvaloniaList<Transform> {}

@:native("Avalonia.Media.TransformGroup")
extern class TransformGroup extends Transform {
	function new();
	var Children:Transforms;
}

@:native("Avalonia.Media.BlurEffect")
extern class BlurEffect implements IEffect {
	function new();
	var Radius:Float;
}

@:native("Avalonia.Media.PathSegment")
extern class PathSegment {}

@:native("Avalonia.Media.PathSegments")
extern class PathSegments extends AvaloniaList<PathSegment> {
	function new();
}

@:native("Avalonia.Media.LineSegment")
extern class LineSegment extends PathSegment {
	function new();
	var Point:Point;
}

@:native("Avalonia.Media.QuadraticBezierSegment")
extern class QuadraticBezierSegment extends PathSegment {
	function new();
	var Point1:Point;
	var Point2:Point;
}

@:native("Avalonia.Media.BezierSegment")
extern class BezierSegment extends PathSegment {
	function new();
	var Point1:Point;
	var Point2:Point;
	var Point3:Point;
}

@:native("Avalonia.Media.PathFigure")
extern class PathFigure {
	function new();
	var StartPoint:Point;
	var IsClosed:Bool;
	var IsFilled:Bool;
	var Segments:PathSegments;
}

@:native("Avalonia.Media.PathFigures")
extern class PathFigures extends AvaloniaList<PathFigure> {}

@:native("Avalonia.Media.PathGeometry")
extern class PathGeometry extends Geometry {
	@:overload function new();
	var Figures:PathFigures;
}

@:native("Avalonia.Media.Imaging.BitmapInterpolationMode")
extern enum BitmapInterpolationMode {
	Unspecified;
	None;
}

@:native("Avalonia.Media.ImmediateDrawingContext")
extern class ImmediateDrawingContext {
	function TryGetFeature(type:cs.system.Type):cs.system.Object;
}

@:native("Avalonia.Rendering.SceneGraph.ICustomDrawOperation")
extern interface ICustomDrawOperation extends IDisposable extends IEquatable_1<ICustomDrawOperation> {
	@:property var Bounds(get, never):Rect;
	function HitTest(p:Point):Bool;
	function Render(context:ImmediateDrawingContext):Void;
}

@:native("Avalonia.Media.DrawingContext")
extern class DrawingContext implements IDisposable {
	function Dispose():Void;
	function Custom(custom:ICustomDrawOperation):Void;
	@:overload function PushClip(clip:Rect):PushedState;
	function PushGeometryClip(clip:Geometry):PushedState;
	@:overload function DrawRectangle(brush:IBrush, pen:IPen, rect:RoundedRect, boxShadows:BoxShadows):Void;
	function FillRectangle(brush:IBrush, rect:Rect, cornerRadius:Single):Void;
	function DrawLine(pen:IPen, p1:Point, p2:Point):Void;
	@:overload function DrawImage(source:IImage, sourceRect:Rect, destRect:Rect):Void;
	@:overload function DrawImage(source:IImage, rect:Rect):Void;
	function DrawGeometry(brush:IBrush, pen:IPen, geometry:Geometry):Void;
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
	static var Rgba8888(default, never):PixelFormat;
	@:overload function Equals(other:PixelFormat):Bool;
}

@:native("Avalonia.Platform.ILockedFramebuffer")
extern interface ILockedFramebuffer extends IDisposable {
	var Address(default, never):IntPtr;
	var RowBytes(default, never):Int;
	var Size(default, never):PixelSize;
	var Format(default, never):PixelFormat;
}

@:native("Avalonia.Media.IImage")
extern interface IImage {}

@:native("Avalonia.Media.Imaging.Bitmap")
extern class Bitmap implements IImage implements IDisposable {
	function Dispose():Void;
	@:overload function Save(fileName:String, quality:Nullable_1<Int>):Void;
	@:overload function Save(stream:Stream, quality:Nullable_1<Int>):Void;
	@:overload function new(stream:Stream);
	var PixelSize(default, never):PixelSize;
	var Dpi(default, never):Vector;
	var Size(default, never):Size;
	@:overload function CopyPixels(buffer:ILockedFramebuffer):Void;
}

@:native("Avalonia.Media.Imaging.RenderTargetBitmap")
extern class RenderTargetBitmap extends Bitmap {
	@:overload function new(pixelSize:PixelSize);
	function Render(visual:haxe.ui.backend.cs.net.Controls.Visual):Void;
	@:overload function CreateDrawingContext():DrawingContext;
}

@:native("Avalonia.Media.Imaging.WriteableBitmap")
extern class WriteableBitmap extends Bitmap {
	@:overload function new(size:PixelSize, dpi:Vector, format:Nullable_1<PixelFormat>, alphaFormat:Nullable_1<AlphaFormat>);
	function Lock():ILockedFramebuffer;
}

@:native("System.Runtime.InteropServices.Marshal")
extern class Marshal {
	@:overload static function ReadInt32(ptr:cs.system.IntPtr, ofs:Int):Int;
	@:overload static function Copy(source:IntPtr, destination:NativeArray<UInt8>, startIndex:Int, length:Int):Void;
	@:overload static function Copy(source:NativeArray<UInt8>, startIndex:Int, destination:IntPtr, length:Int):Void;
	@:overload static function WriteByte(ptr:IntPtr, value:UInt8):Void;
	@:overload static function WriteInt32(ptr:IntPtr, ofs:Int, val:Int):Void;
}

@:native("System.Runtime.CompilerServices.ConditionalWeakTable`2")
extern class ConditionalWeakTable<K, V> {
	function new();
	function GetOrCreateValue(key:K):V;
	function Remove(key:K):Bool;
}
