package haxe.ui.backend.cs.native;

/**
 * Externs for the C# side of haxeui-cs (`native/*.cs`, namespace HaxeUICs).
 * Each extern carries the name of the C# type it binds.
 */

@:native("HaxeUICs.ICallback")
extern interface ICallback {
	function Invoke():Void;
}

@:native("HaxeUICs.IHostListener")
extern interface IHostListener {
	function OnReady():Void;
	function OnResize(width:Float, height:Float):Void;
	function OnClosed():Void;
}

@:native("HaxeUICs.Host")
extern class Host {
	static var Window(default, null):Dynamic;
	static var Root(default, null):UIPanel;
	static var Title:String;
	static var ClientWidth(default, null):Float;
	static var ClientHeight(default, null):Float;

	static function RunDesktop(listener:IHostListener, title:String, width:Int, height:Int):Void;
	#if haxeui_cs_headless
	static function StartHeadless(listener:IHostListener, width:Int, height:Int):Void;
	#end
	static function Post(callback:ICallback):Void;
	static function StartTimer(milliseconds:Int, callback:ICallback):Dynamic;
	static function StopTimer(handle:Dynamic):Void;
	static function CloseWindow():Void;
	static function Exit(code:Int):Void;
}

/** Avalonia's base control: only ever passed back to C#. **/
@:native("Avalonia.Controls.Control")
extern class Control {
	var IsVisible(default, null):Bool;
}

@:native("HaxeUICs.UIPanel")
extern class UIPanel extends Control {
	function new():Void;

	var Left(default, null):Float;
	var Top(default, null):Float;
	var W(default, null):Float;
	var H(default, null):Float;
	var ClipEnabled(default, null):Bool;
	var ClipLeft(default, null):Float;
	var ClipTop(default, null):Float;
	var ClipWidth(default, null):Float;
	var ClipHeight(default, null):Float;
	var ChildCount(default, null):Int;

	function SetBounds(left:Float, top:Float, width:Float, height:Float):Void;
	function SetClip(enabled:Bool, left:Float, top:Float, width:Float, height:Float):Void;
	function SetVisible(visible:Bool):Void;
	function InsertChild(child:Control, index:Int):Void;
	function RemoveChild(child:Control):Void;
	function MoveChild(child:Control, index:Int):Void;
	function IndexOfChild(child:Control):Int;
	function AddContent(content:Control):Void;
}

#if haxeui_cs_headless
@:native("HaxeUICs.HeadlessDriver")
extern class HeadlessDriver {
	static function Pump(frames:Int):Void;
	static function ResizeWindow(width:Int, height:Int):Void;
	static function Capture(path:String):Void;
	static function PixelAt(x:Int, y:Int):Int;
}
#end
