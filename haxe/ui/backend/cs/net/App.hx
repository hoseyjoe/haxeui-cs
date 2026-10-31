package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.system.Action_1;
import cs.system.EventArgs;
import cs.system.EventHandler;
import cs.system.EventHandler_1;
import cs.system.Func_1;
import cs.system.IServiceProvider;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Net;

/** Externs for Avalonia's application, its start-up and its window, written by hand as hxc binds them. */
@:native("Avalonia.Styling.IStyle")
extern interface IStyle {}

@:native("Avalonia.Styling.Styles")
extern class Styles extends AvaloniaObject implements IStyle {
	function Add(item:IStyle):Void;
}

@:native("Avalonia.Themes.Simple.SimpleTheme")
extern class SimpleTheme extends Styles {
	function new(sp:IServiceProvider);
}

@:native("Avalonia.Controls.ShutdownMode")
extern enum ShutdownMode {
	OnLastWindowClose;
	OnMainWindowClose;
	OnExplicitShutdown;
}

@:native("Avalonia.Controls.WindowState")
extern enum WindowState {
	Normal;
	Minimized;
	Maximized;
	FullScreen;
}

@:native("Avalonia.Controls.WindowIcon")
extern class WindowIcon {
	@:overload function new(stream:Stream);
}

@:native("Avalonia.Controls.WindowClosingEventArgs")
extern class WindowClosingEventArgs extends EventArgs {
	var Cancel:Bool;
}

@:native("Avalonia.Controls.WindowBase")
extern class WindowBase extends TopLevel {
	@:event private var Opened:EventHandler;
	function add_Opened(value:EventHandler):Void;
	function remove_Opened(value:EventHandler):Void;
}

@:native("Avalonia.Controls.Window")
extern class Window extends WindowBase {
	function new();
	var Title:String;
	var CanResize:Bool;
	var WindowState:WindowState;
	var Icon:WindowIcon;
	@:overload function Show():Void;
	@:overload function Close():Void;
	@:event private var Closing:EventHandler_1<WindowClosingEventArgs>;
	function add_Closing(value:EventHandler_1<WindowClosingEventArgs>):Void;
	function remove_Closing(value:EventHandler_1<WindowClosingEventArgs>):Void;
}

@:native("Avalonia.Controls.ApplicationLifetimes.IApplicationLifetime")
extern interface IApplicationLifetime {}

@:native("Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime")
extern interface IClassicDesktopStyleApplicationLifetime extends IApplicationLifetime {
	var ShutdownMode:ShutdownMode;
	var MainWindow:Window;
}

@:native("Avalonia.Controls.ApplicationLifetimes.ISingleViewApplicationLifetime")
extern interface ISingleViewApplicationLifetime extends IApplicationLifetime {
	var MainView:Control;
}

@:native("Avalonia.Application")
extern class Application extends AvaloniaObject {
	function new();
	var Styles(default, never):Styles;
	var ApplicationLifetime(default, never):IApplicationLifetime;
	function Initialize():Void;
	function OnFrameworkInitializationCompleted():Void;
}

@:native("Avalonia.AppBuilder")
extern class AppBuilder {
	@:overload static function Configure<TApp>(factory:Func_1<TApp>):AppBuilder;
	function SetupWithoutStarting():AppBuilder;
}

@:native("Avalonia.SkiaApplicationExtensions")
extern class SkiaApplicationExtensions {
	static function UseSkia(builder:AppBuilder):AppBuilder;
}

#if haxeui_cs_headless
@:native("Avalonia.Headless.AvaloniaHeadlessPlatformOptions")
extern class AvaloniaHeadlessPlatformOptions {
	function new();
	var UseHeadlessDrawing:Bool;
}

@:native("Avalonia.Headless.AvaloniaHeadlessPlatformExtensions")
extern class AvaloniaHeadlessPlatformExtensions {
	static function UseHeadless(builder:AppBuilder, options:AvaloniaHeadlessPlatformOptions):AppBuilder;
}

@:native("Avalonia.Headless.HeadlessWindowExtensions")
extern class HeadlessWindowExtensions {
	static function CaptureRenderedFrame(topLevel:TopLevel):haxe.ui.backend.cs.net.Media.WriteableBitmap;
}
#end

#if haxeui_cs_android
@:native("Android.Util.DisplayMetrics")
extern class DisplayMetrics {
	var Density:Single;
}

@:native("Android.Content.Res.Resources")
extern class AndroidResources {
	var DisplayMetrics(default, never):DisplayMetrics;
}

@:native("Android.Content.Context")
extern class AndroidContext {
	var Resources(default, never):AndroidResources;
}

@:native("Android.App.Application")
extern class AndroidApplication {
	static var Context(default, never):AndroidContext;
}
#else
@:native("Avalonia.AppBuilderDesktopExtensions")
extern class AppBuilderDesktopExtensions {
	static function UsePlatformDetect(builder:AppBuilder):AppBuilder;
}

@:native("Avalonia.ClassicDesktopStyleApplicationLifetimeExtensions")
extern class ClassicDesktopStyleApplicationLifetimeExtensions {
	@:overload static function StartWithClassicDesktopLifetime(builder:AppBuilder, args:NativeArray<String>,
		lifetimeBuilder:Action_1<IClassicDesktopStyleApplicationLifetime>):Int;
}
#end
