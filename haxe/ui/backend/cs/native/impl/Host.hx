package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Action;
import cs.system.Console;
import cs.system.Environment;
import cs.system.EventArgs;
import cs.system.EventHandler;
import cs.system.EventHandler_1;
import cs.system.Exception;
import cs.system.Func_1;
import cs.system.Nullable_1;
import cs.system.TimeSpan;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.UIEvents;
import haxe.ui.backend.cs.net.App;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Controls.TopLevel as TopLevelControl;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Threading;

/** A parameterless callback Haxe can implement. */
@:native("HaxeUICs.ICallback")
@:nativeGen
interface ICallback {
	function Invoke():Void;
}

/** Runs Haxe's own event loop once; answers how long until it next needs to (ms, -1: no idea). */
@:native("HaxeUICs.IEventsPump")
@:nativeGen
interface IEventsPump {
	function Pump():Float;
}

/** What the host tells the HaxeUI side about the window's life. */
@:native("HaxeUICs.IHostListener")
@:nativeGen
interface IHostListener {
	function OnReady():Void;
	function OnResize(width:Float, height:Float):Void;
	function OnClosed():Void;
}

/** Asked before a close the app did not ask for: false keeps the window open. */
@:native("HaxeUICs.ICloseListener")
@:nativeGen
interface ICloseListener {
	function OnCloseRequested():Bool;
}

/** Asked when the user presses back (Android): true when it was handled. */
@:native("HaxeUICs.IBackListener")
@:nativeGen
interface IBackListener {
	function OnBack():Bool;
}

/** Told when the app goes to the background (Android's onPause). */
@:native("HaxeUICs.IPauseListener")
@:nativeGen
interface IPauseListener {
	function OnPause():Void;
}

@:native("HaxeUICs.HostApplication")
@:nativeGen
class HostApplication extends Application {
	public function new() {
		super();
	}

	override public function Initialize():Void {
		// Window chrome and TextBox templates come from a theme; HaxeUI paints everything else itself.
		Styles.Add(new SimpleTheme(null));
	}

	override public function OnFrameworkInitializationCompleted():Void {
		var lifetime = ApplicationLifetime;
		if (Std.isOfType(lifetime, IClassicDesktopStyleApplicationLifetime)) {
			var desktop:IClassicDesktopStyleApplicationLifetime = cast lifetime;
			desktop.ShutdownMode = ShutdownMode.OnMainWindowClose;
			var window = Host.CreateWindow();
			var opened:EventHandler = function(s:Dynamic, e:EventArgs) {
				Host.Listener.OnReady();
			};
			window.add_Opened(opened);
			desktop.MainWindow = window;
		} else if (Std.isOfType(lifetime, ISingleViewApplicationLifetime)) {
			// Android: no window, one view the activity shows. Root is that view, and the Haxe
			// program starts here, once per process (an activity made again reattaches Root).
			(cast lifetime : ISingleViewApplicationLifetime).MainView = Host.Root;
			Host.EnterOnce();
		}
		super.OnFrameworkInitializationCompleted();
	}
}

/** The Avalonia application, its one window and its dispatcher, as HaxeUI needs them. */
@:native("HaxeUICs.Host")
@:nativeGen
class Host {
	public static var Listener:IHostListener;

	static var _title = "";
	static var _width = 800;
	static var _height = 600;
	static var _resizable = true;
	static var _minWidth = 0;
	static var _minHeight = 0;
	static var _maximized = false;
	static var _icon:NativeArray<UInt8>;

	public static var Window(default, null):Window;

	static var _root:UIPanel;

	/**
	 * The panel root components live in. It exists before the window does, so components added
	 * early (HaxeUIApp's preloader) are already there when the window takes it as its content.
	 */
	public static var Root(get, never):UIPanel;

	static function get_Root():UIPanel {
		if (_root == null) {
			_root = new UIPanel();
		}
		return _root;
	}

	public static var Title(get, set):String;

	static function get_Title():String {
		return Window != null ? Window.Title : _title;
	}

	static function set_Title(value:String):String {
		_title = value != null ? value : "";
		if (Window != null) {
			Window.Title = _title;
		}
		return value;
	}

	static var _screenKinds = 0;
	static var _screenListener:IPanelListener;
	static var _screenEvents:EventRouter;

	/**
	 * Window-wide input for HaxeUI's Screen: hears events even after a component handled them.
	 * May be called before the window exists (Toolkit.init does); it attaches on creation.
	 */
	public static function ListenScreen(kinds:Int, listener:IPanelListener):Void {
		_screenKinds = kinds;
		_screenListener = listener;
		if (_screenEvents != null) {
			_screenEvents.Update(kinds, listener);
		}
	}

	/** Window options beyond size and title; kept until the window exists. */
	public static function ConfigureWindow(resizable:Bool, minWidth:Int, minHeight:Int, maximized:Bool):Void {
		_resizable = resizable;
		_minWidth = minWidth < 0 ? 0 : minWidth;
		_minHeight = minHeight < 0 ? 0 : minHeight;
		_maximized = maximized;
		if (Window != null) {
			ApplyOptions(Window);
		}
	}

	static function ApplyOptions(window:Window):Void {
		window.CanResize = _resizable;
		window.MinWidth = _minWidth;
		window.MinHeight = _minHeight;
		if (_maximized) {
			window.WindowState = WindowState.Maximized;
		}
		if (_icon != null) {
			try {
				window.Icon = new WindowIcon(new MemoryStream(_icon));
			} catch (e:Exception) {} // not an image: no icon
		}
	}

	/** The window's icon, from image bytes (PNG and the like). */
	public static function SetIcon(image:NativeArray<UInt8>):Void {
		_icon = image;
		if (Window != null) {
			ApplyOptions(Window);
		}
	}

	public static var HasIcon(get, never):Bool;

	static function get_HasIcon():Bool {
		return Window != null && Window.Icon != null;
	}

	public static var IsResizable(get, never):Bool;

	static function get_IsResizable():Bool {
		return Window != null ? Window.CanResize : _resizable;
	}

	public static var MinWidth(get, never):Float;

	static function get_MinWidth():Float {
		return Window != null ? Window.MinWidth : _minWidth;
	}

	public static var MinHeight(get, never):Float;

	static function get_MinHeight():Float {
		return Window != null ? Window.MinHeight : _minHeight;
	}

	public static var IsMaximized(get, never):Bool;

	static function get_IsMaximized():Bool {
		return Window != null ? Window.WindowState == WindowState.Maximized : _maximized;
	}

	public static var ClientWidth(get, never):Float;

	static function get_ClientWidth():Float {
		return Window != null ? Window.ClientSize.Width : _singleView && Root.Bounds.Width > 0 ? Root.Bounds.Width : _width;
	}

	public static var ClientHeight(get, never):Float;

	static function get_ClientHeight():Float {
		return Window != null ? Window.ClientSize.Height : _singleView && Root.Bounds.Height > 0 ? Root.Bounds.Height : _height;
	}

	/**
	 * What holds Root: the window on the desktop, the activity's view on Android (null until
	 * Root is shown). The clipboard and the file pickers go through it.
	 */
	public static var TopLevel(get, never):TopLevel;

	public static function get_TopLevel():TopLevel {
		if (Window != null) {
			return Window;
		}
		return _root != null ? TopLevelControl.GetTopLevel(_root) : null;
	}

	/** Device pixels per Avalonia unit (Android's density; the desktop's display scale). */
	public static var RenderScaling(get, never):Float;

	static function get_RenderScaling():Float {
		#if haxeui_cs_android
		// The display's density, which is what Avalonia lays the view out by: the view's
		// TopLevel.RenderScaling still says 1 when OnReady comes (its ClientSize is already the
		// surface over the density), and an app scales HaxeUI from this before its first component.
		// The two agree once the view is attached, unless the display's density changes under a
		// running app; an app that fixes its scale at start, as heaps-android's do, keeps it.
		var resources = AndroidApplication.Context.Resources;
		var metrics = resources != null ? resources.DisplayMetrics : null;
		if (metrics == null) {
			return 1;
		}
		return metrics.Density;
		#else
		var top = TopLevel;
		return top != null ? top.RenderScaling : 1;
		#end
	}

	// ---- Android: one view, no window ----

	/** The Haxe program's entry point, which the Android app calls once Avalonia is up. */
	public static var Entry:Action;

	/** The app's private files folder (Android); also the working directory there. */
	public static var FilesDir:String;

	/** Sends the app to the background without ending it (Android's back when nothing takes it). */
	public static var LeaveApp:Action;

	/** Ends the app's activity (app.exit() on Android). */
	public static var FinishApp:Action;

	static var _singleView = false;
	static var _entered = false;
	static var _readySent = false;
	static var _attachedTo:TopLevel;
	static var _onBackRequested:EventHandler_1<RoutedEventArgs>;

	/** Runs Entry, the first time only: Avalonia initialises once per process. */
	public static function EnterOnce():Void {
		if (_entered || Entry == null) {
			return;
		}
		_entered = true;
		Entry.Invoke();
	}

	/**
	 * Android: Root is the view Android shows, so there is nothing to start or block on. Returns
	 * at once; OnReady comes when Root is first shown with a size, OnResize after that.
	 */
	public static function RunSingleView(listener:IHostListener):Void {
		Listener = listener;
		_singleView = true;
		var attached:EventHandler_1<VisualTreeAttachmentEventArgs> = function(s:Dynamic, e:VisualTreeAttachmentEventArgs) {
			AttachSingleView();
		};
		Root.add_AttachedToVisualTree(attached);
		var changed:EventHandler_1<AvaloniaPropertyChangedEventArgs> = function(s:Dynamic, e:AvaloniaPropertyChangedEventArgs) {
			if (e.Property == Visual.BoundsProperty) {
				SingleViewResized();
			}
		};
		Root.add_PropertyChanged(changed);
		if (TopLevelControl.GetTopLevel(Root) != null) {
			AttachSingleView();
		}
	}

	/**
	 * Root is in a (new) view: screen input, the background and back go to that view, and it
	 * fills the screen with the system bars hidden (a swipe from an edge shows them for a while).
	 */
	static function AttachSingleView():Void {
		var top = TopLevelControl.GetTopLevel(Root);
		if (top == null || top == _attachedTo) {
			return;
		}
		if (_onBackRequested == null) {
			var requested:EventHandler_1<RoutedEventArgs> = function(s:Dynamic, e:RoutedEventArgs) {
				OnBackRequested(e);
			};
			_onBackRequested = requested;
		}
		if (_attachedTo != null) {
			_attachedTo.remove_BackRequested(_onBackRequested);
		}
		_attachedTo = top;
		top.Background = new SolidColorBrush(Color.FromUInt32(_background), 1.0);
		top.add_BackRequested(_onBackRequested);
		var insets = top.InsetsManager;
		if (insets != null) {
			insets.DisplayEdgeToEdgePreference = true;
			insets.IsSystemBarVisible = new Nullable_1(false);
		}
		_screenEvents = new EventRouter(top, true);
		_screenEvents.Update(_screenKinds, _screenListener);
		SingleViewResized();
	}

	/**
	 * Back: the app's BackButton listeners first; when none takes it, the app goes to the
	 * background as Android's home screen apps do. Always handled, so Avalonia never ends the
	 * activity itself.
	 */
	static function OnBackRequested(e:RoutedEventArgs):Void {
		e.Handled = true;
		if (!RaiseBack() && LeaveApp != null) {
			LeaveApp.Invoke();
		}
	}

	static function SingleViewResized():Void {
		// Avalonia lays the view out at 1x1 before Android has given it a surface: HaxeUI is
		// ready at the screen's real size, not at that, so a size of 1 is not one yet.
		var bounds = Root.Bounds;
		if (bounds.Width <= 1 || bounds.Height <= 1 || Listener == null) {
			return;
		}
		if (!_readySent) {
			_readySent = true;
			Listener.OnReady();
			return;
		}
		Listener.OnResize(bounds.Width, bounds.Height);
	}

	static function Configure():AppBuilder {
		var factory:Func_1<HostApplication> = function() {
			return new HostApplication();
		};
		return AppBuilder.Configure(factory);
	}

	/** Starts Avalonia with a desktop window; blocks until that window closes. */
	public static function RunDesktop(listener:IHostListener, title:String, width:Int, height:Int):Void {
		Listener = listener;
		_title = title != null ? title : "";
		_width = width;
		_height = height;
		#if haxeui_cs_android
		throw new cs.system.PlatformNotSupportedException("haxeui-cs: Android starts the app from MainActivity, not RunDesktop");
		#else
		ClassicDesktopStyleApplicationLifetimeExtensions.StartWithClassicDesktopLifetime(AppBuilderDesktopExtensions.UsePlatformDetect(Configure()),
			new NativeArray<String>(0), null);
		#end
	}

	#if haxeui_cs_headless
	/** Starts Avalonia headless (real Skia drawing, no OS window); returns once ready. */
	public static function StartHeadless(listener:IHostListener, width:Int, height:Int):Void {
		Listener = listener;
		_width = width;
		_height = height;
		var options = new AvaloniaHeadlessPlatformOptions();
		options.UseHeadlessDrawing = false;
		AvaloniaHeadlessPlatformExtensions.UseHeadless(SkiaApplicationExtensions.UseSkia(Configure()), options).SetupWithoutStarting();
		var window = CreateWindow();
		window.Show();
		Dispatcher.UIThread.RunJobs(null);
		listener.OnReady();
	}
	#end

	public static function CreateWindow():Window {
		var window = new Window();
		window.Title = _title;
		window.Width = _width;
		window.Height = _height;
		window.Background = new SolidColorBrush(Color.FromUInt32(_background), 1.0);
		window.Content = cast Root;
		ApplyOptions(window);
		var changed:EventHandler_1<AvaloniaPropertyChangedEventArgs> = function(s:Dynamic, e:AvaloniaPropertyChangedEventArgs) {
			if (e.Property == TopLevelControl.ClientSizeProperty && Listener != null) {
				Listener.OnResize(window.ClientSize.Width, window.ClientSize.Height);
			}
		};
		window.add_PropertyChanged(changed);
		var closing:EventHandler_1<WindowClosingEventArgs> = function(s:Dynamic, e:WindowClosingEventArgs) {
			if (_closeByApp) {
				return;
			}
			if (!AskClose()) {
				e.Cancel = true;
			}
			WakeEventsPump(); // the handler may have started work (a prompt) of its own
		};
		window.add_Closing(closing);
		var closed:EventHandler = function(s:Dynamic, e:EventArgs) {
			if (Listener != null) {
				Listener.OnClosed();
			}
		};
		window.add_Closed(closed);
		_screenEvents = new EventRouter(window, true);
		_screenEvents.Update(_screenKinds, _screenListener);
		Window = window;
		return window;
	}

	/**
	 * Toolkit.scale: the root panel, and so every root component and popup, drawn this much
	 * larger from the window's top left. Pointer positions measured against the root stay in
	 * HaxeUI's units, and text and images render at the scaled size, not stretched.
	 */
	public static function SetScale(scaleX:Float, scaleY:Float):Void {
		if (scaleX <= 0 || scaleY <= 0) {
			return;
		}
		Root.RenderTransformOrigin = new RelativePoint(0, 0, RelativeUnit.Absolute);
		Root.RenderTransform = scaleX == 1 && scaleY == 1 ? null : new ScaleTransform(scaleX, scaleY);
	}

	/**
	 * What shows behind the components, as 0xAARRGGBB (white until the app says otherwise): an
	 * app's dark theme sets it, as html5 sets the page's and Heaps the engine's clear colour.
	 * Kept until the window exists.
	 */
	public static function SetBackground(argb:UInt):Void {
		_background = argb;
		if (Window != null) {
			Window.Background = new SolidColorBrush(Color.FromUInt32(argb), 1.0);
		} else if (_attachedTo != null) {
			_attachedTo.Background = new SolidColorBrush(Color.FromUInt32(argb), 1.0);
		}
	}

	static var _background:UInt = 0xFFFFFFFF;

	/** The cursor the whole window shows (a splitter drag), or null for none. */
	public static var ScreenCursorName(default, null):String;

	public static function SetScreenCursor(css:String):Void {
		ScreenCursorName = css;
		if (Window != null) {
			Window.Cursor = UIStyle.CursorFor(css);
		}
	}

	public static function Post(callback:ICallback):Void {
		var run:Action = function() {
			callback.Invoke();
			WakeEventsPump();
		};
		Dispatcher.UIThread.Post(run, DispatcherPriority.Default);
	}

	/**
	 * Runs the callback with the next frame, as a browser's requestAnimationFrame: work that
	 * re-schedules itself (HaxeUI's animations) then advances once per frame instead of spinning.
	 * Before the window exists it is simply queued.
	 */
	public static function NextFrame(callback:ICallback):Void {
		_frameQueue.push(callback);
		if (_frameTimer == null) {
			var tick:EventHandler = function(s:Dynamic, e:EventArgs) {
				RunFrame();
			};
			_frameTimer = new DispatcherTimer(TimeSpan.FromMilliseconds(FrameMilliseconds), DispatcherPriority.Normal, tick);
		}
		if (!_frameTimer.IsEnabled) {
			_frameTimer.Start();
		}
	}

	static inline var FrameMilliseconds = 16;
	static var _frameQueue = new Array<ICallback>();
	static var _frameTimer:DispatcherTimer;

	/** Runs one frame's batch; anything queued while it runs waits for the next frame. */
	public static function RunFrame():Void {
		if (_frameQueue.length == 0) {
			if (_frameTimer != null) {
				_frameTimer.Stop();
			}
			return;
		}
		var batch = _frameQueue;
		_frameQueue = new Array<ICallback>();
		for (callback in batch) {
			// Each on its own, as a browser runs requestAnimationFrame callbacks: one that throws
			// is reported and the rest of its frame still runs.
			try {
				callback.Invoke();
			} catch (e:Dynamic) {
				Report("a callLater", e);
			}
		}
		WakeEventsPump();
	}

	static function Report(what:String, error:Dynamic):Void {
		Console.Error.WriteLine("haxeui-cs: " + what + " threw: " + Std.string(error));
	}

	// Haxe's event loop (haxe.Timer, haxe.MainLoop, results posted from other threads) gets a
	// turn when it says it next needs one, and straight after anything that may have given it
	// work (a HaxeUI frame, input, a posted callback). With nothing scheduled it is polled
	// slowly, for work posted from other threads: an idle app is not woken 100 times a second.
	static inline var IdleEventsPollMs = 250.0;
	static var _eventsPump:IEventsPump;
	static var _eventsTimer:DispatcherTimer;

	/** How often the Haxe event loop has been pumped (for the idle check). */
	public static var EventsPumps(default, null):Int = 0;

	public static function StartEventsPump(pump:IEventsPump):Void {
		_eventsPump = pump;
		var tick:EventHandler = function(s:Dynamic, e:EventArgs) {
			PumpEvents();
		};
		_eventsTimer = new DispatcherTimer(TimeSpan.FromMilliseconds(1), DispatcherPriority.Normal, tick);
		_eventsTimer.Start();
	}

	static function PumpEvents():Void {
		EventsPumps++;
		var next = _eventsPump.Pump();
		var wait = next < 0 ? IdleEventsPollMs : Math.max(1, Math.min(IdleEventsPollMs, next));
		_eventsTimer.Interval = TimeSpan.FromMilliseconds(wait);
	}

	/** Gives the Haxe event loop a turn as soon as the dispatcher is free. */
	public static function WakeEventsPump():Void {
		if (_eventsTimer == null || _eventsTimer.Interval.TotalMilliseconds <= 1) {
			return;
		}
		_eventsTimer.Stop();
		_eventsTimer.Interval = TimeSpan.FromMilliseconds(1);
		_eventsTimer.Start();
	}

	public static function StartTimer(milliseconds:Int, callback:ICallback):Dynamic {
		var tick:EventHandler = function(s:Dynamic, e:EventArgs) {
			callback.Invoke();
			WakeEventsPump();
		};
		var timer = new DispatcherTimer(TimeSpan.FromMilliseconds(milliseconds < 1 ? 1 : milliseconds), DispatcherPriority.Normal, tick);
		timer.Start();
		return timer;
	}

	public static function StopTimer(handle:Dynamic):Void {
		if (Std.isOfType(handle, DispatcherTimer)) {
			(cast handle : DispatcherTimer).Stop();
		}
	}

	/** Renders the window's content as it stands to a PNG; false when there is no window yet. */
	public static function CaptureWindow(path:String):Bool {
		if (Window == null) {
			return false;
		}
		var size = new PixelSize(Std.int(Math.max(1, ClientWidth)), Std.int(Math.max(1, ClientHeight)));
		var bitmap = new RenderTargetBitmap(size);
		try {
			bitmap.Render(Window);
			bitmap.Save(path, new Nullable_1(100));
		} catch (e:Exception) {
			bitmap.Dispose();
			throw e;
		}
		bitmap.Dispose();
		return true;
	}

	/**
	 * What a close the app did not ask for (the close button, Alt+F4) consults; null lets
	 * every close through. A close by CloseWindow (app.exit()) never asks it.
	 */
	public static var CloseListener:ICloseListener;

	static var _closeByApp = false;

	/**
	 * Whether the window may close now, as the close listener answers. One that throws is
	 * reported and the window closes: an app's bug never makes a window that can't be closed.
	 */
	public static function AskClose():Bool {
		var listener = CloseListener;
		if (listener == null) {
			return true;
		}
		try {
			return listener.OnCloseRequested();
		} catch (e:Dynamic) {
			Report("a close request handler", e);
			return true;
		}
	}

	/** The press under way makes no click when released: a long press that showed a tooltip. */
	public static function SuppressNextClick():Void {
		EventRouter.SuppressNextClick();
	}

	/** What back asks (BackButton's listeners); null takes no back. */
	public static var BackListener:IBackListener;

	/** What going to the background tells (AppLifecycle.onPause); null tells no one. */
	public static var PauseListener:IPauseListener;

	/**
	 * Back was pressed: whether the app took it. One that throws is reported and back counts
	 * as not taken, so the app still leaves rather than swallowing back for good.
	 */
	public static function RaiseBack():Bool {
		var listener = BackListener;
		if (listener == null) {
			return false;
		}
		var taken = false;
		try {
			taken = listener.OnBack();
		} catch (e:Dynamic) {
			Report("a back handler", e);
		}
		WakeEventsPump(); // the handler may have started work (a timer) of its own
		return taken;
	}

	/** The app is going to the background. One that throws is reported and the app still goes. */
	public static function RaisePause():Void {
		try {
			if (PauseListener != null) {
				PauseListener.OnPause();
			}
		} catch (e:Dynamic) {
			Report("a pause handler", e);
		}
		WakeEventsPump(); // the handler may have started work (a save) of its own
	}

	public static function CloseWindow():Void {
		if (Window == null) {
			// Android: app.exit() ends the activity, then the app, as closing the window does.
			if (!_singleView) {
				return;
			}
			if (FinishApp != null) {
				FinishApp.Invoke();
			}
			if (Listener != null) {
				Listener.OnClosed();
			}
			return;
		}
		_closeByApp = true;
		Window.Close();
	}

	public static function Exit(code:Int):Void {
		UIClipboard.Flush(); // what the app copied stays on the clipboard after it ends, as in any program
		Environment.Exit(code);
	}
}
