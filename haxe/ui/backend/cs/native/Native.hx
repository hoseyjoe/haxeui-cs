package haxe.ui.backend.cs.native;

/**
 * Externs for the C# side of haxeui-cs (`native/*.cs`, namespace HaxeUICs).
 * Each extern carries the name of the C# type it binds.
 */

@:native("HaxeUICs.ICallback")
extern interface ICallback {
	function Invoke():Void;
}

@:native("HaxeUICs.IEventsPump")
extern interface IEventsPump {
	function Pump():Float;
}

@:native("HaxeUICs.IHostListener")
extern interface IHostListener {
	function OnReady():Void;
	function OnResize(width:Float, height:Float):Void;
	function OnClosed():Void;
}

@:native("HaxeUICs.ICloseListener")
extern interface ICloseListener {
	function OnCloseRequested():Bool;
}

@:native("HaxeUICs.IBackListener")
extern interface IBackListener {
	function OnBack():Bool;
}

@:native("HaxeUICs.IPauseListener")
extern interface IPauseListener {
	function OnPause():Void;
}

@:native("HaxeUICs.UIClipboard")
extern class UIClipboard {
	static function SetText(text:String, sensitive:Bool):Bool;
	static function GetText():String;
	static function Clear():Bool;
}

@:native("HaxeUICs.Host")
extern class Host {
	static var Window(default, null):Dynamic;
	static var Root(default, null):UIPanel;
	static var Title:String;
	static var ClientWidth(default, null):Float;
	static var ClientHeight(default, null):Float;
	static var ScreenCursorName(default, null):String;
	static var RenderScaling(default, null):Float;
	static var FilesDir:String;

	static function RunDesktop(listener:IHostListener, title:String, width:Int, height:Int):Void;
	static function RunSingleView(listener:IHostListener):Void;
	#if haxeui_cs_headless
	static function StartHeadless(listener:IHostListener, width:Int, height:Int):Void;
	#end
	static function Post(callback:ICallback):Void;
	static function NextFrame(callback:ICallback):Void;
	static function StartTimer(milliseconds:Int, callback:ICallback):Dynamic;
	static function StopTimer(handle:Dynamic):Void;
	static function CloseWindow():Void;
	static var CloseListener:ICloseListener;
	static function AskClose():Bool;
	static var BackListener:IBackListener;
	static var PauseListener:IPauseListener;
	static function RaiseBack():Bool;
	static function RaisePause():Void;
	static function SuppressNextClick():Void;
	static function WakeEventsPump():Void;
	static function CaptureWindow(path:String):Bool;
	static function ListenScreen(kinds:Int, listener:IPanelListener):Void;
	static function Exit(code:Int):Void;
	static function SetScreenCursor(css:String):Void;
	static function SetBackground(argb:UInt):Void;
	static function SetScale(scaleX:Float, scaleY:Float):Void;
	static function StartEventsPump(pump:IEventsPump):Void;
	static var EventsPumps(default, null):Int;
	static function ConfigureWindow(resizable:Bool, minWidth:Int, minHeight:Int, maximized:Bool):Void;
	static function SetIcon(image:haxe.io.BytesData):Void;
	static var HasIcon(default, null):Bool;
	static var IsResizable(default, null):Bool;
	static var MinWidth(default, null):Float;
	static var MinHeight(default, null):Float;
	static var IsMaximized(default, null):Bool;
}

typedef IPanelListener = haxe.ui.backend.cs.native.impl.UIEvents.IPanelListener;

typedef NativeEvents = haxe.ui.backend.cs.native.impl.UIEvents.NativeEvents;

typedef KeyCodes = haxe.ui.backend.cs.native.impl.UIEvents.KeyCodes;

@:native("HaxeUICs.IFileDialogListener")
extern interface IFileDialogListener {
	function OnFiles(paths:cs.NativeArray<String>):Void;
	function OnCancelled():Void;
	function OnFailed(message:String):Void;
}

@:native("HaxeUICs.FileDialogs")
extern class FileDialogs {
	static var TestResponse:cs.NativeArray<String>;

	static function OpenFiles(title:String, multiple:Bool, patterns:cs.NativeArray<String>, patternNames:cs.NativeArray<String>, listener:IFileDialogListener):Void;
	static function SaveFile(title:String, suggestedName:String, patterns:cs.NativeArray<String>, patternNames:cs.NativeArray<String>, listener:IFileDialogListener):Void;
	static function OpenFolder(title:String, multiple:Bool, defaultPath:String, listener:IFileDialogListener):Void;
}

typedef PickedFiles = haxe.ui.backend.cs.native.impl.PickedFiles;

typedef Control = haxe.ui.backend.cs.net.Controls.Control;

@:native("HaxeUICs.UIPanel")
extern class UIPanel extends Control {
	function new():Void;

	function LinksChanged():Void;

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
	var CursorName(default, null):String;

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
	function SetGraphics(graphics:UIGraphics):Void;
	function SetCursorSuppressed(suppressed:Bool):Void;
	function SetColorMatrix(matrix:cs.NativeArray<Single>):Void;
	function SetRotation(degrees:Float):Void;
	/** Drawn scaled about its top-left (layout and hit box untouched); composes with SetRotation. **/
	function SetScale(scaleX:Float, scaleY:Float):Void;
	/** A fade multiplied into the style's opacity. **/
	function SetAlpha(alpha:Float):Void;
	function SetClipInset(top:Float, right:Float, bottom:Float, left:Float):Void;
}

typedef UIGraphics = haxe.ui.backend.cs.native.impl.UIGraphics;

typedef UILayers = haxe.ui.backend.cs.native.impl.UILayers;

typedef UIText = haxe.ui.backend.cs.native.impl.UIText;

typedef UIFonts = haxe.ui.backend.cs.native.impl.UIFonts;

typedef ColorMatrix = haxe.ui.backend.cs.native.impl.ColorMatrix;

typedef Inflate = haxe.ui.backend.cs.native.impl.Inflate;

typedef Deflate = haxe.ui.backend.cs.native.impl.Deflate;

typedef UIImage = haxe.ui.backend.cs.native.impl.UIImage;

typedef UIImageView = haxe.ui.backend.cs.native.impl.UIImage.UIImageView;

typedef ITextInputListener = haxe.ui.backend.cs.native.impl.UITextInput.ITextInputListener;

typedef UITextInput = haxe.ui.backend.cs.native.impl.UITextInput;

typedef UIStyle = haxe.ui.backend.cs.native.impl.UIStyle;

#if haxeui_cs_headless
@:native("HaxeUICs.HeadlessDriver")
extern class HeadlessDriver {
	static function Pump(frames:Int):Void;
	static function ResizeWindow(width:Int, height:Int):Void;
	static function Capture(path:String):Void;
	static function PixelAt(x:Int, y:Int):Int;
	static function PixelsAt(x:Int, y:Int, w:Int, h:Int):cs.NativeArray<Int>;
	static function ClipboardFormat(name:String):String;
	static function MouseMove(x:Float, y:Float):Void;
	static function MouseDown(x:Float, y:Float, button:Int):Void;
	static function MouseUp(x:Float, y:Float, button:Int):Void;
	static function Wheel(x:Float, y:Float, deltaY:Float, deltaX:Float):Void;
	static function KeyStroke(name:String, ctrl:Bool, shift:Bool):Void;
	static function TypeText(text:String):Void;
	static function StartHttpServer(root:String, delayMs:Int):Int;
	static var HttpHits(default, null):Int;
	static function StopHttpServer():Void;
}
#end
