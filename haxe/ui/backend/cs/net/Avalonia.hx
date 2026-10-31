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
