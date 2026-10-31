package haxe.ui.backend.cs.net;

/** Externs for Avalonia's value types, written by hand as hxc binds them. */
@:native("Avalonia.PixelSize")
@:struct
extern class PixelSize {
	function new(width:Int, height:Int);
	var Width(default, never):Int;
	var Height(default, never):Int;
}

@:native("Avalonia.Vector")
@:struct
extern class Vector {
	function new(x:Float, y:Float);
	var X(default, never):Float;
	var Y(default, never):Float;
}

@:native("Avalonia.RelativePoint")
@:struct
extern class RelativePoint {}

@:native("Avalonia.Point")
@:struct
extern class Point {
	function new(x:Float, y:Float);
	var X(default, never):Float;
	var Y(default, never):Float;
}

@:native("Avalonia.Matrix")
@:struct
extern class Matrix {
	@:overload function new(scaleX:Float, skewY:Float, skewX:Float, scaleY:Float, offsetX:Float, offsetY:Float);
	static var Identity(default, never):Matrix;
	var M11(default, never):Float;
	var M12(default, never):Float;
	var M21(default, never):Float;
	var M22(default, never):Float;
	var M31(default, never):Float;
	var M32(default, never):Float;
	@:overload function Equals(other:Matrix):Bool;
}

@:native("Avalonia.Rect")
@:struct
extern class Rect {
	@:overload function new(x:Float, y:Float, width:Float, height:Float);
	var Left(default, never):Float;
	var Top(default, never):Float;
	var Right(default, never):Float;
	var Bottom(default, never):Float;
	var Width(default, never):Float;
	var Height(default, never):Float;
	function Union(rect:Rect):Rect;
	function Intersect(rect:Rect):Rect;
	function TransformToAABB(matrix:Matrix):Rect;
}

@:native("Avalonia.Size")
@:struct
extern class Size {
	var Width(default, never):Float;
	var Height(default, never):Float;
}

@:native("Avalonia.Thickness")
@:struct
extern class Thickness {
	@:overload function new(uniform:Float);
}
