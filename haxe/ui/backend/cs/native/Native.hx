package haxe.ui.backend.cs.native;

/**
 * Externs for the C# side of haxeui-cs (`native/*.cs`, namespace HaxeUICs).
 * Each extern carries the name of the C# type it binds.
 */

typedef ICallback = haxe.ui.backend.cs.native.impl.Host.ICallback;

typedef IEventsPump = haxe.ui.backend.cs.native.impl.Host.IEventsPump;

typedef IHostListener = haxe.ui.backend.cs.native.impl.Host.IHostListener;

typedef ICloseListener = haxe.ui.backend.cs.native.impl.Host.ICloseListener;

typedef IBackListener = haxe.ui.backend.cs.native.impl.Host.IBackListener;

typedef IPauseListener = haxe.ui.backend.cs.native.impl.Host.IPauseListener;

typedef Host = haxe.ui.backend.cs.native.impl.Host.Host;

typedef HostApplication = haxe.ui.backend.cs.native.impl.Host.HostApplication;

typedef UIClipboard = haxe.ui.backend.cs.native.impl.UIClipboard;

typedef IPanelListener = haxe.ui.backend.cs.native.impl.UIEvents.IPanelListener;

typedef NativeEvents = haxe.ui.backend.cs.native.impl.UIEvents.NativeEvents;

typedef KeyCodes = haxe.ui.backend.cs.native.impl.UIEvents.KeyCodes;

typedef IFileDialogListener = haxe.ui.backend.cs.native.impl.FileDialogs.IFileDialogListener;

typedef FileDialogs = haxe.ui.backend.cs.native.impl.FileDialogs;

typedef PickedFiles = haxe.ui.backend.cs.native.impl.PickedFiles;

typedef Control = haxe.ui.backend.cs.net.Controls.Control;

typedef UIPanel = haxe.ui.backend.cs.native.impl.UIPanel;

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
