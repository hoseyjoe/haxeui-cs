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
	static function ListenScreen(kinds:Int, listener:IPanelListener):Void;
	static function Exit(code:Int):Void;
}

@:native("HaxeUICs.IPanelListener")
extern interface IPanelListener {
	function OnPointer(kind:Int, screenX:Float, screenY:Float, buttonDown:Bool, ctrl:Bool, shift:Bool, alt:Bool, wheelDelta:Float, nativeEvent:Dynamic):Void;
	function OnKey(kind:Int, keyCode:Int, ctrl:Bool, shift:Bool, alt:Bool, nativeEvent:Dynamic):Void;
}

@:native("HaxeUICs.NativeEvents")
extern class NativeEvents {
	static function Cancel(nativeEvent:Dynamic):Void;
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
	function ApplyStyle(style:UIStyle):Void;
	function Listen(kinds:Int, listener:IPanelListener):Void;
}

@:native("HaxeUICs.UIText")
extern class UIText extends Control {
	function new():Void;

	var Text:String;
	var FontSize(default, null):Float;
	var IsBold(default, null):Bool;
	var MeasuredWidth(default, null):Float;
	var MeasuredHeight(default, null):Float;

	function SetFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool):Void;
	function SetColor(argb:UInt):Void;
	function SetAlign(align:Int):Void;
	function SetWrap(wrap:Bool):Void;
	function SetBounds(left:Float, top:Float, width:Float, height:Float):Void;
	function MeasureText(maxWidth:Float):Void;
}

@:native("HaxeUICs.UIImage")
extern class UIImage {
	var Width(default, null):Int;
	var Height(default, null):Int;

	static function FromBytes(data:haxe.io.BytesData):UIImage;
}

@:native("HaxeUICs.UIImageView")
extern class UIImageView extends Control {
	function new():Void;

	var W(default, null):Float;
	var H(default, null):Float;

	function SetImage(image:UIImage):Void;
	function SetBounds(left:Float, top:Float, width:Float, height:Float):Void;
	function SetClip(enabled:Bool, left:Float, top:Float, width:Float, height:Float):Void;
}

@:native("HaxeUICs.UIStyle")
extern class UIStyle {
	function new():Void;

	var BackgroundColor:UInt;
	var BackgroundColorEnd:UInt;
	var GradientStyle:Int;
	var BackgroundOpacity:Float;

	var BorderLeft:Float;
	var BorderTop:Float;
	var BorderRight:Float;
	var BorderBottom:Float;
	var BorderLeftColor:UInt;
	var BorderTopColor:UInt;
	var BorderRightColor:UInt;
	var BorderBottomColor:UInt;
	var BorderOpacity:Float;

	var RadiusTL:Float;
	var RadiusTR:Float;
	var RadiusBR:Float;
	var RadiusBL:Float;

	var Opacity:Float;
	var Cursor:String;

	var BackgroundImage:UIImage;
	var ClipL:Float;
	var ClipT:Float;
	var ClipR:Float;
	var ClipB:Float;
	var SliceL:Float;
	var SliceT:Float;
	var SliceR:Float;
	var SliceB:Float;
	var Repeat:Int;
}

#if haxeui_cs_headless
@:native("HaxeUICs.HeadlessDriver")
extern class HeadlessDriver {
	static function Pump(frames:Int):Void;
	static function ResizeWindow(width:Int, height:Int):Void;
	static function Capture(path:String):Void;
	static function PixelAt(x:Int, y:Int):Int;
	static function MouseMove(x:Float, y:Float):Void;
	static function MouseDown(x:Float, y:Float, button:Int):Void;
	static function MouseUp(x:Float, y:Float, button:Int):Void;
	static function Wheel(x:Float, y:Float, deltaY:Float):Void;
}
#end
