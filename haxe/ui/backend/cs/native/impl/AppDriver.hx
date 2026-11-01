package haxe.ui.backend.cs.native.impl;

#if haxeui_cs_drive
import cs.NativeArray;
import cs.system.Console;
import cs.system.Convert;
import cs.system.Delegate;
import cs.system.Enum;
import cs.system.Environment;
import cs.system.EventArgs;
import cs.system.EventHandler;
import cs.system.EventHandler_1;
import cs.system.IntPtr;
import cs.system.TimeSpan;
import cs.system.Type;
import cs.system.collections.IEnumerable;
import cs.system.reflection.Assembly;
import cs.system.reflection.BindingFlags;
import cs.system.reflection.ConstructorInfo;
import cs.system.reflection.PropertyInfo;
import cs.system.reflection.TargetInvocationException;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.impl.Host.Host;
import haxe.ui.backend.cs.native.impl.Host.ICallback;
import haxe.ui.backend.cs.net.App.Window;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls.AvaloniaPropertyChangedEventArgs;
import haxe.ui.backend.cs.net.Controls.TopLevel as TopLevelControl;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Threading;

/**
 * Drives a running app from outside, for a driver such as heaps-drive: input is handed to the
 * window as raw Avalonia events, through the `Input` delegate of its platform impl, which is where
 * the OS's own events arrive. Nothing reaches the OS's input queue, so the user's mouse and
 * keyboard are never involved. Positions are in window units, relative to the client area.
 * Buttons: 0 left, 1 middle, 2 right. Everything here runs on the UI thread.
 *
 * Avalonia hides what this needs (the raw event classes, the platform impl, the keyboard device are
 * private API), and Haxe's C# builds against Avalonia's reference assemblies, which leave them out.
 * So it all goes through .NET reflection, on the assemblies the running process loaded, and every
 * member looked up is checked on first use: an Avalonia upgrade that moves one fails with its name.
 */
@:native("HaxeUICs.AppDriver")
class AppDriver {
	// ---- input ----

	public static function MouseMove(x:Float, y:Float):Void {
		RawPointer("Move", x, y);
	}

	public static function MouseDown(x:Float, y:Float, button:Int):Void {
		CheckButton("MouseDown", button);
		RawPointer(button == 2 ? "RightButtonDown" : button == 1 ? "MiddleButtonDown" : "LeftButtonDown", x, y);
		_buttons |= ButtonBit(button);
	}

	public static function MouseUp(x:Float, y:Float, button:Int):Void {
		CheckButton("MouseUp", button);
		_buttons &= ~ButtonBit(button);
		RawPointer(button == 2 ? "RightButtonUp" : button == 1 ? "MiddleButtonUp" : "LeftButtonUp", x, y);
	}

	/**
	 * The next press starts a new click, however soon after the last one it comes. Avalonia counts
	 * presses close in time and place as a double (then triple) click, and a text field answers a
	 * double click by selecting a word, so two separate clicks a driver sends back to back would act
	 * as one. A driver calls this before a press that is a click of its own; a double click is two
	 * presses with no call between. Does nothing while a button is held: that press belongs to the
	 * click or drag under way.
	 *
	 * It works on the clock the events carry (Now): from here on every event is stamped later by
	 * whatever it takes for the next press to be more than DoubleClickPastMs after the last one.
	 * The one mouse device is kept, so nothing else changes for the pointer (a new device would see
	 * the pointer leave and enter whatever it is over). The stamps stay in step with each other and
	 * never run backwards; they are ahead of the real clock by the sum of those shortfalls.
	 */
	public static function NewClick():Void {
		Init();
		if (_buttons != 0) {
			return;
		}
		var shortfall = _lastPressMs + DoubleClickPastMs - StampMs();
		if (shortfall > 0) {
			_skewMs += shortfall;
		}
	}

	/** Longer than any double-click time the OS allows (Windows: 5 s at most), so a press this long after another is a first click. */
	static inline var DoubleClickPastMs = 5001.0;
	static var _skewMs = 0.0;
	static var _lastPressMs = -1e18;

	/** deltaY > 0 scrolls up (away from the user), as a wheel does. */
	public static function Wheel(x:Float, y:Float, deltaY:Float, deltaX:Float):Void {
		Init();
		var args = new NativeArray<Dynamic>(6);
		args[0] = _mouse;
		args[1] = Now();
		args[2] = InputRoot();
		args[3] = new Point(x, y);
		args[4] = new Vector(deltaX, deltaY);
		args[5] = Modifiers();
		Deliver(Make(_wheelArgs, args));
	}

	/** Avalonia's Key value of the key named so ("Enter", "Tab", "A"), or -1 if there is no such key. */
	public static function KeyCode(avaloniaKeyName:String):Int {
		Init();
		if (avaloniaKeyName == null || !Enum.IsDefined(_keyType, avaloniaKeyName)) {
			return -1;
		}
		return Convert.ToInt32(Enum.Parse(_keyType, avaloniaKeyName));
	}

	public static function KeyDown(code:Int):Void {
		CheckKeyCode("KeyDown", code);
		if (Host.Window == null) {
			throw NoWindow; // before the key counts as held
		}
		Init();
		if (_held.indexOf(code) < 0) {
			_held.push(code);
		}
		RawKey("KeyDown", code);
	}

	public static function KeyUp(code:Int):Void {
		CheckKeyCode("KeyUp", code);
		Init();
		_held.remove(code);
		RawKey("KeyUp", code);
	}

	/** Text arriving as typed input (what a keyboard layout produces), into whatever has keyboard focus. */
	public static function Text(text:String):Void {
		Init();
		var args = new NativeArray<Dynamic>(4);
		args[0] = _keyboard;
		args[1] = Now();
		args[2] = InputRoot();
		args[3] = text;
		Deliver(Make(_textArgs, args));
	}

	// ---- capture ----

	/**
	 * A region of the window's client area as PNG bytes, rendered as Host.CaptureWindow does (96 dpi,
	 * so one image pixel is one window unit). w <= 0 takes the whole client area. The region is cut
	 * to the client area; null when none of it is inside (or there is no window yet).
	 */
	public static function CapturePng(x:Int, y:Int, w:Int, h:Int):Null<NativeArray<UInt8>> {
		var window = Host.Window;
		if (window == null) {
			return null;
		}
		var width = Std.int(Math.max(1, Host.ClientWidth));
		var height = Std.int(Math.max(1, Host.ClientHeight));
		var left = 0, top = 0, right = width, bottom = height;
		var whole = w <= 0;
		if (!whole) {
			left = Std.int(Math.max(0, x));
			top = Std.int(Math.max(0, y));
			right = Std.int(Math.min(width, x + w));
			bottom = Std.int(Math.min(height, y + h));
			if (right <= left || bottom <= top) {
				return null;
			}
		}
		var full = new RenderTargetBitmap(new PixelSize(width, height));
		return Scope.get(full, () -> {
			full.Render(window);
			var png = new MemoryStream();
			if (whole) {
				full.Save(png, null);
			} else {
				var part = new RenderTargetBitmap(new PixelSize(right - left, bottom - top));
				Scope.run(part, () -> {
					var context = part.CreateDrawingContext();
					Scope.run(context, () -> {
						context.DrawImage(full, new Rect(left, top, right - left, bottom - top), new Rect(0, 0, right - left, bottom - top));
					});
					part.Save(png, null);
				});
			}
			return png.ToArray();
		});
	}

	// ---- the window ----

	static var _offScreen = false;

	/**
	 * Before the window exists: whether it is put off every display (see ApplyWindow for how, what that
	 * pins for good, and that the pinning is Windows-only). Either way it is never activated (no focus
	 * taken from anyone: on Windows it has WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW in both modes), and out of the taskbar. Input held by an earlier window is let go.
	 */
	public static function SetWindow(offScreen:Bool):Void {
		if (Host.Window != null) {
			throw "AppDriver: SetWindow comes before the window exists; this one is already open";
		}
		_offScreen = offScreen;
		_buttons = 0;
		_held = [];
		if (_ready) {
			_mouse = NewMouse(_core);
		}
	}

	/**
	 * Host.CreateWindow, under -D haxeui_cs_drive: the window as SetWindow asked, before it is shown.
	 * Showing it never activates it.
	 *
	 * Put off screen, on Windows the hook is the guarantee: a hook on the window procedure (Avalonia's
	 * Win32Properties.AddWndProcHookCallback) rewrites the position of every WM_WINDOWPOSCHANGING to the
	 * off-screen target, so neither Windows' default position (the window is created at CW_USEDEFAULT)
	 * nor Avalonia pulling a window back onto a display can put it anywhere else, even for the instant of
	 * its first show. Position is also set before the show: in the runs observed it was redundant (either
	 * alone held), and off Windows, where the hook does nothing, it is all that holds the window.
	 *
	 * What follows from that, and is not a bug:
	 * - The pin lasts the window's life: on Windows a Position set later is silently overridden.
	 * - The target is worked out once, from the displays as they are now. A display added on the right
	 *   mid-run can cover the window; WindowIsOnADisplay then says so.
	 * - Once the window is open the position is confirmed: if it is on a display, the run stops with an
	 *   error (thrown from the Opened event, which Avalonia does not catch: the process ends, with the
	 *   message on stderr). On Windows that means the target itself was on a display; elsewhere, that
	 *   Position did not hold.
	 */
	public static function ApplyWindow(window:Window):Void {
		// First, so the styles are in from the window's creation (setting ShowInTaskbar below restyles it). In both
		// modes: a visible driven window (SetWindow(false)) is as non-activating and tool-windowed as an off-screen one,
		// so Windows never makes it the active window either. Only the position hold is for an off-screen window.
		AddWindowStyles(window);
		if (_offScreen) {
			HoldOffScreen(window);
		}
		Set(window, "ShowActivated", false);
		Set(window, "ShowInTaskbar", false);
		if (!_offScreen) {
			return;
		}
		var opened:EventHandler = function(s:Dynamic, e:EventArgs) {
			if (get_WindowIsOnADisplay()) {
				throw "AppDriver: the window is on a display after it opened, though it was asked to be off every one";
			}
		};
		window.add_Opened(opened);
	}

	/**
	 * Windows' WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW on the window, through Avalonia's own hook
	 * (Win32Properties.AddWindowStylesCallback): Windows itself then never makes it the active window
	 * (when the user closes theirs and it picks the next in z-order, say), and Alt+Tab does not list it.
	 * Avalonia's delegate type is a nested one, so the callback is bound to a static method by CreateDelegate.
	 */
	static function AddWindowStyles(window:Window):Void {
		AddCallback(window, "AddWindowStylesCallback", "CustomWindowStylesCallback", WindowStyles, "Add");
	}

	/**
	 * The off-screen hold: the target worked out once, a hook on the window procedure that writes it into
	 * every WM_WINDOWPOSCHANGING, and Position set to it now, while the window is still hidden.
	 */
	static function HoldOffScreen(window:Window):Void {
		var target = OffScreenTarget(window);
		OffScreenHook.X = target.x;
		OffScreenHook.Y = target.y;
		AddCallback(window, "AddWndProcHookCallback", "CustomWndProcHookCallback", OffScreenHook, "Proc");
		var args = new NativeArray<Dynamic>(2);
		args[0] = target.x;
		args[1] = target.y;
		var core:Assembly = cs.Lib.toNativeType(cast Key).Assembly;
		Set(window, "Position", Ctor(Find(core, "Avalonia.PixelPoint"), ["Int32", "Int32"]).Invoke(args));
	}

	/** Win32Properties.<adder>(window, a delegate of the nested type <callbackName> bound to hookClass.<hookMethod>), all found by reflection and checked. */
	static function AddCallback(window:Window, adder:String, callbackName:String, hookClass:Class<Dynamic>, hookMethod:String):Void {
		var controls:Assembly = cs.Lib.toNativeType(TopLevelControl).Assembly;
		var properties = Find(controls, "Avalonia.Controls.Win32Properties");
		var callbackType = properties.GetNestedType(callbackName);
		var parameterTypes = new NativeArray<Type>(2);
		parameterTypes[0] = cs.Lib.toNativeType(TopLevelControl);
		parameterTypes[1] = callbackType;
		var add = callbackType == null ? null : properties.GetMethod(adder, parameterTypes);
		var hook = cs.Lib.toNativeType(hookClass).GetMethod(hookMethod);
		if (callbackType == null || add == null || hook == null) {
			throw "AppDriver: Avalonia.Controls.Win32Properties." + adder + " (or its callback type " + callbackName + ") is missing";
		}
		var args = new NativeArray<Dynamic>(2);
		args[0] = window;
		args[1] = Delegate.CreateDelegate(callbackType, hook);
		add.Invoke(null, args);
	}

	/** Right of the rightmost display (and a margin more), level with the topmost: physical pixels. */
	static function OffScreenTarget(window:Window):{x:Int, y:Int} {
		var x = 0, y = 0, any = false;
		for (bounds in Displays(window)) {
			var right:Int = Get(bounds, "Right");
			var top:Int = Get(bounds, "Y");
			x = any ? Std.int(Math.max(x, right)) : right;
			y = any ? Std.int(Math.min(y, top)) : top;
			any = true;
		}
		return {x: x + 200, y: y};
	}

	/** The bounds (PixelRect) of every display; a named error when the window can say none, since "off every display" would mean nothing. */
	static function Displays(window:Window):Array<Dynamic> {
		var screens = Get(window, "Screens");
		if (screens == null) {
			throw "AppDriver: the window has no Screens, so it cannot be told where the displays are";
		}
		var all = Items(Get(screens, "All"));
		if (all.length == 0) {
			throw "AppDriver: Screens.All is empty, so it cannot be told where the displays are";
		}
		return [for (screen in all) Get(screen, "Bounds")];
	}

	/** The client size, in window units. */
	public static function Resize(w:Int, h:Int):Void {
		var window = Host.Window;
		if (window == null) {
			throw NoWindow;
		}
		if (w < 1 || h < 1) {
			throw "AppDriver: Resize(" + w + ", " + h + ") is not a size";
		}
		EndResize(window); // a newer Resize replaces one still settling
		if (Math.abs(w - window.ClientSize.Width) < 0.5 && Math.abs(h - window.ClientSize.Height) < 0.5) {
			return; // nothing will change, so nothing is listened for
		}
		window.Width = w;
		window.Height = h;
		// On Windows an open window ends up smaller than the Width and Height it is given (6 x 17 units,
		// with Avalonia 12.1.4 here), and Avalonia then takes the smaller size as the Width and Height. So
		// what is asked for is raised by what is missing each time the client size changes, up to three
		// times. A second after the call this stops whatever has happened (a size that cannot be had, a
		// minimum size, no change at all), so a later size change is never pushed back towards this ask.
		var askedWidth:Float = w;
		var askedHeight:Float = h;
		var corrections = 0;
		var settle:EventHandler_1<AvaloniaPropertyChangedEventArgs> = null;
		settle = function(s:Dynamic, e:AvaloniaPropertyChangedEventArgs) {
			if (e.Property != TopLevelControl.ClientSizeProperty) {
				return;
			}
			var missingWidth = w - window.ClientSize.Width;
			var missingHeight = h - window.ClientSize.Height;
			if ((Math.abs(missingWidth) < 0.5 && Math.abs(missingHeight) < 0.5) || corrections >= 3) {
				EndResize(window);
				return;
			}
			corrections++;
			askedWidth += missingWidth;
			askedHeight += missingHeight;
			window.Width = askedWidth;
			window.Height = askedHeight;
		};
		_resizing = settle;
		window.add_PropertyChanged(settle);
		var deadline:EventHandler = function(s:Dynamic, e:EventArgs) {
			EndResize(window);
			var width = window.ClientSize.Width;
			var height = window.ClientSize.Height;
			if (Math.abs(w - width) >= 0.5 || Math.abs(h - height) >= 0.5) {
				// from a timer: reported, not thrown; Host.ClientWidth and ClientHeight hold the real size
				Console.Error.WriteLine("AppDriver: Resize(" + w + ", " + h + ") left the client area " + Math.round(width) + "x" + Math.round(height));
			}
		};
		_resizeDeadline = new DispatcherTimer(TimeSpan.FromMilliseconds(ResizeDeadlineMs), DispatcherPriority.Normal, deadline);
		_resizeDeadline.Start();
	}

	static inline var ResizeDeadlineMs = 1000;
	static var _resizing:EventHandler_1<AvaloniaPropertyChangedEventArgs>;
	static var _resizeDeadline:DispatcherTimer;

	/** Ends the correction a Resize started, if one is still going: its handler and its deadline timer. */
	static function EndResize(window:Window):Void {
		if (_resizing != null) {
			window.remove_PropertyChanged(_resizing);
			_resizing = null;
		}
		if (_resizeDeadline != null) {
			_resizeDeadline.Stop();
			_resizeDeadline = null;
		}
	}

	/** Whether any of the window's client area is on a display; a window put off screen is not. */
	public static var WindowIsOnADisplay(get, never):Bool;

	static function get_WindowIsOnADisplay():Bool {
		var window = Host.Window;
		if (window == null) {
			throw NoWindow;
		}
		var position = Get(window, "Position");
		var left:Int = Get(position, "X");
		var top:Int = Get(position, "Y");
		var right = left + Math.round(window.ClientSize.Width * window.RenderScaling);
		var bottom = top + Math.round(window.ClientSize.Height * window.RenderScaling);
		for (bounds in Displays(window)) {
			var screenRight:Int = Get(bounds, "Right");
			var screenBottom:Int = Get(bounds, "Bottom");
			var screenLeft:Int = Get(bounds, "X");
			var screenTop:Int = Get(bounds, "Y");
			if (left < screenRight && right > screenLeft && top < screenBottom && bottom > screenTop) {
				return true;
			}
		}
		return false;
	}

	/** Whether the window is Avalonia's active one: what activating it would make true, and nothing here does. */
	public static var WindowIsActive(get, never):Bool;

	static function get_WindowIsActive():Bool {
		var window = Host.Window;
		if (window == null) {
			throw NoWindow;
		}
		return Get(window, "IsActive");
	}

	static var _closed:Array<ICallback> = [];

	/**
	 * Calls back when the window has closed, BEFORE the app is told of it: Host's own Closed handler runs
	 * RunClosed first, because what it tells the app ends the process (Host.Exit), and a handler added
	 * to the window's Closed event after Host's would never be reached. So a driver's cleanup (a
	 * drive.json to delete) runs on any close, the app's own or the user's, not only on a `quit`.
	 */
	public static function OnClosed(callback:ICallback):Void {
		if (Host.Window == null) {
			throw NoWindow;
		}
		_closed.push(callback);
	}

	/** Host's Closed handler, first: the OnClosed callbacks, each once. A callback that throws is reported and the rest still run, since the app must still end. */
	public static function RunClosed():Void {
		var all = _closed;
		_closed = [];
		for (callback in all) {
			try {
				callback.Invoke();
			} catch (e:Dynamic) {
				Console.Error.WriteLine("AppDriver: an OnClosed callback threw: " + e);
			}
		}
	}

	static function Get(target:Dynamic, name:String):Dynamic {
		var property = Property((cast target : cs.system.Object).GetType(), name, INSTANCE_ANY);
		return property.GetValue(target, null);
	}

	static function Set(target:Dynamic, name:String, value:Dynamic):Void {
		var property = Property((cast target : cs.system.Object).GetType(), name, INSTANCE_ANY);
		property.SetValue(target, value, null);
	}

	static function Items(list:Dynamic):Array<Dynamic> {
		var all:Array<Dynamic> = [];
		var each = (cast list : IEnumerable).GetEnumerator();
		while (each.MoveNext()) {
			all.push(each.Current);
		}
		return all;
	}

	// ---- held state ----

	// RawInputModifiers bits of the mouse buttons held, and the codes of the keys held: the modifiers
	// come from the keys, so Control stays down while either Ctrl does.
	static var _buttons:Int = 0;
	static var _held:Array<Int> = [];

	static function Modifiers():Dynamic {
		var bits = _buttons;
		for (code in _held) {
			bits |= ModifierKeyBit(code);
		}
		return Enum.ToObject(_modifiersType, bits);
	}

	static function CheckButton(call:String, button:Int):Void {
		if (button < 0 || button > 2) {
			throw "AppDriver: " + call + " has no button " + button + " (0 left, 1 middle, 2 right)";
		}
	}

	/** KeyCode answers -1 for a key it does not know: that must not go on as a key. */
	static function CheckKeyCode(call:String, code:Int):Void {
		if (code < 0) {
			throw "AppDriver: " + call + "(" + code + ") is not a key code (KeyCode answers -1 for a name it does not know)";
		}
	}

	static function ButtonBit(button:Int):Int {
		return button == 2 ? _right : button == 1 ? _middle : _left;
	}

	static function ModifierKeyBit(code:Int):Int {
		return _modifierKeys.exists(code) ? _modifierKeys.get(code) : 0;
	}

	// ---- events ----

	static inline var NoWindow = "AppDriver: the window does not exist yet";

	static function RawPointer(type:String, x:Float, y:Float):Void {
		Init();
		if (type.indexOf("ButtonDown") >= 0) {
			_lastPressMs = StampMs();
		}
		var args = new NativeArray<Dynamic>(6);
		args[0] = _mouse;
		args[1] = Now();
		args[2] = InputRoot();
		args[3] = Enum.Parse(_pointerType, type);
		args[4] = new Point(x, y);
		args[5] = Modifiers();
		Deliver(Make(_pointerArgs, args));
	}

	static function RawKey(type:String, code:Int):Void {
		var name = Enum.GetName(_keyType, code);
		var physical = name != null && Enum.IsDefined(_physicalKeyType, name) ? Enum.Parse(_physicalKeyType, name) : Enum.Parse(_physicalKeyType, "None");
		var args = new NativeArray<Dynamic>(9);
		args[0] = _keyboard;
		args[1] = Now();
		args[2] = InputRoot();
		args[3] = Enum.Parse(_keyEventType, type);
		args[4] = Enum.ToObject(_keyType, code);
		args[5] = Modifiers();
		args[6] = physical;
		args[7] = null;
		args[8] = Enum.Parse(_keyDeviceType, "Keyboard");
		Deliver(Make(_keyArgs, args));
	}

	/** What the platform names as an event's root: the window's (internal) InputRoot, which the window itself is not. */
	static function InputRoot():Dynamic {
		if (Host.Window == null) {
			throw NoWindow;
		}
		var root = _inputRoot.GetValue(Host.Window, null);
		if (root == null) {
			throw "AppDriver: the window has no InputRoot yet";
		}
		return root;
	}

	/** Environment.TickCount64 as the unsigned 64-bit value the raw events take. */
	static function Now():Dynamic {
		return Convert.ChangeType(StampMs(), _uint64Type);
	}

	/** The time stamped on an event, in ms: the real clock plus what NewClick has added. */
	static function StampMs():Float {
		return Math.floor(Convert.ToDouble(_tickCount.GetValue(null, null))) + _skewMs;
	}

	static function Make(ctor:ConstructorInfo, args:NativeArray<Dynamic>):Dynamic {
		try {
			return ctor.Invoke(args);
		} catch (e:TargetInvocationException) {
			throw e.InnerException;
		}
	}

	/** Hands one raw event to the window, as the platform would, and lets Haxe's loop see what it started. */
	static function Deliver(event:Dynamic):Void {
		var window = Host.Window;
		if (window == null) {
			throw NoWindow;
		}
		var impl = _platformImpl.GetValue(window, null);
		if (impl == null) {
			throw "AppDriver: the window has no PlatformImpl (it is closed)";
		}
		var input:Delegate = _inputProperty.GetValue(impl, null);
		if (input == null) {
			throw "AppDriver: the window's PlatformImpl.Input is not set";
		}
		var args = new NativeArray<Dynamic>(1);
		args[0] = event;
		try {
			input.DynamicInvoke(args);
		} catch (e:TargetInvocationException) {
			throw e.InnerException;
		}
		Host.WakeEventsPump();
	}

	// ---- reflection, once ----

	static var _ready = false;
	static var _core:Assembly;
	static var _mouse:Dynamic;
	static var _keyboard:Dynamic;
	static var _platformImpl:PropertyInfo;
	static var _inputRoot:PropertyInfo;
	static var _inputProperty:PropertyInfo;
	static var _pointerArgs:ConstructorInfo;
	static var _wheelArgs:ConstructorInfo;
	static var _keyArgs:ConstructorInfo;
	static var _textArgs:ConstructorInfo;
	static var _tickCount:PropertyInfo;
	static var _uint64Type:Type;
	static var _pointerType:Type;
	static var _keyEventType:Type;
	static var _keyDeviceType:Type;
	static var _modifiersType:Type;
	static var _keyType:Type;
	static var _physicalKeyType:Type;
	static var _left:Int;
	static var _middle:Int;
	static var _right:Int;
	static var _modifierKeys:Map<Int, Int>;

	// BindingFlags: Instance 4, Static 8, Public 16, NonPublic 32.
	static inline var INSTANCE_ANY:Int = 4 | 16 | 32;
	static inline var STATIC_ANY:Int = 8 | 16 | 32;

	static function Init():Void {
		if (_ready) {
			return;
		}
		var core:Assembly = cs.Lib.toNativeType(cast Key).Assembly; // Avalonia.Base
		_core = core;
		var controls:Assembly = cs.Lib.toNativeType(TopLevelControl).Assembly; // Avalonia.Controls

		_uint64Type = cs.Lib.toNativeType(cs.types.UInt64);
		// By reflection because hxc binds System.Environment from an older framework's metadata, which has no TickCount64.
		_tickCount = Property(cs.Lib.toNativeType(Environment), "TickCount64", STATIC_ANY);
		_keyType = Find(core, "Avalonia.Input.Key");
		_physicalKeyType = Find(core, "Avalonia.Input.PhysicalKey");
		_modifiersType = Find(core, "Avalonia.Input.RawInputModifiers");
		_pointerType = Find(core, "Avalonia.Input.Raw.RawPointerEventType");
		_keyEventType = Find(core, "Avalonia.Input.Raw.RawKeyEventType");
		_keyDeviceType = Find(core, "Avalonia.Input.KeyDeviceType");

		_pointerArgs = Ctor(Find(core, "Avalonia.Input.Raw.RawPointerEventArgs"), ["IInputDevice", "UInt64", "IInputRoot", "RawPointerEventType", "Point", "RawInputModifiers"]);
		_wheelArgs = Ctor(Find(core, "Avalonia.Input.Raw.RawMouseWheelEventArgs"), ["IInputDevice", "UInt64", "IInputRoot", "Point", "Vector", "RawInputModifiers"]);
		_keyArgs = Ctor(Find(core, "Avalonia.Input.Raw.RawKeyEventArgs"),
			["IInputDevice", "UInt64", "IInputRoot", "RawKeyEventType", "Key", "RawInputModifiers", "PhysicalKey", "String", "KeyDeviceType"]);
		_textArgs = Ctor(Find(core, "Avalonia.Input.Raw.RawTextInputEventArgs"), ["IKeyboardDevice", "UInt64", "IInputRoot", "String"]);

		var topLevel = Find(controls, "Avalonia.Controls.TopLevel");
		_platformImpl = Property(topLevel, "PlatformImpl", INSTANCE_ANY);
		_inputRoot = Property(topLevel, "InputRoot", INSTANCE_ANY);
		_inputProperty = Property(Find(controls, "Avalonia.Platform.ITopLevelImpl"), "Input", INSTANCE_ANY);

		_mouse = NewMouse(core);

		var keyboardType = Find(core, "Avalonia.Input.KeyboardDevice");
		_keyboard = Property(keyboardType, "Instance", STATIC_ANY).GetValue(null, null);
		if (_keyboard == null) {
			throw "AppDriver: Avalonia.Input.KeyboardDevice.Instance is null";
		}

		_left = ModifierValue("LeftMouseButton");
		_middle = ModifierValue("MiddleMouseButton");
		_right = ModifierValue("RightMouseButton");
		_modifierKeys = new Map();
		for (name in ["LeftCtrl", "RightCtrl"]) {
			_modifierKeys.set(Convert.ToInt32(Enum.Parse(_keyType, name)), ModifierValue("Control"));
		}
		for (name in ["LeftShift", "RightShift"]) {
			_modifierKeys.set(Convert.ToInt32(Enum.Parse(_keyType, name)), ModifierValue("Shift"));
		}
		for (name in ["LeftAlt", "RightAlt"]) {
			_modifierKeys.set(Convert.ToInt32(Enum.Parse(_keyType, name)), ModifierValue("Alt"));
		}
		_ready = true;
	}

	/** A mouse device of this driver's own, so no state of a real mouse's is shared. */
	static function NewMouse(core:Assembly):Dynamic {
		var pointerClass = Find(core, "Avalonia.Input.Pointer");
		var nextId = pointerClass.GetMethod("GetNextFreeId");
		if (nextId == null) {
			throw "AppDriver: Avalonia.Input.Pointer.GetNextFreeId is missing";
		}
		var pointerArgs = new NativeArray<Dynamic>(3);
		pointerArgs[0] = nextId.Invoke(null, null);
		pointerArgs[1] = Enum.Parse(Find(core, "Avalonia.Input.PointerType"), "Mouse");
		pointerArgs[2] = true;
		var pointer = Ctor(pointerClass, ["Int32", "PointerType", "Boolean"]).Invoke(pointerArgs);
		var deviceArgs = new NativeArray<Dynamic>(1);
		deviceArgs[0] = pointer;
		return Ctor(Find(core, "Avalonia.Input.MouseDevice"), ["Pointer"]).Invoke(deviceArgs);
	}

	static function ModifierValue(name:String):Int {
		if (!Enum.IsDefined(_modifiersType, name)) {
			throw "AppDriver: Avalonia.Input.RawInputModifiers." + name + " is missing";
		}
		return Convert.ToInt32(Enum.Parse(_modifiersType, name));
	}

	static function Find(assembly:Assembly, name:String):Type {
		var type = assembly.GetType(name);
		if (type == null) {
			throw "AppDriver: Avalonia has no type " + name + " in " + assembly.GetName().Name;
		}
		return type;
	}

	static function Property(type:Type, name:String, flags:Int):PropertyInfo {
		var bindingFlags:BindingFlags = cast flags;
		var property = type.GetProperty(name, bindingFlags);
		if (property == null) {
			throw "AppDriver: " + type.FullName + "." + name + " is missing";
		}
		return property;
	}

	/** The constructor of `type` whose parameter types are named so, in order. */
	static function Ctor(type:Type, parameterTypes:Array<String>):ConstructorInfo {
		var all = type.GetConstructors();
		for (i in 0...all.Length) {
			var parameters = all[i].GetParameters();
			if (parameters.Length != parameterTypes.length) {
				continue;
			}
			var same = true;
			for (j in 0...parameters.Length) {
				if (parameters[j].ParameterType.Name != parameterTypes[j]) {
					same = false;
					break;
				}
			}
			if (same) {
				return all[i];
			}
		}
		throw "AppDriver: " + type.FullName + " has no constructor (" + parameterTypes.join(", ") + ")";
	}
}

/**
 * Avalonia's Win32Properties.CustomWindowStylesCallback, `(uint style, uint exStyle) (uint, uint)`:
 * the extended styles with WS_EX_TOOLWINDOW (0x80) and WS_EX_NOACTIVATE (0x08000000) added.
 */
@:native("HaxeUICs.WindowStyles")
@:nativeGen
class WindowStyles {
	public static function Add(style:UInt, exStyle:UInt):ValueTuple2<UInt, UInt> {
		return new ValueTuple2<UInt, UInt>(style, exStyle | (0x80 : UInt) | (0x08000000 : UInt));
	}
}

/**
 * Avalonia's Win32Properties.CustomWndProcHookCallback, `IntPtr (IntPtr hWnd, uint msg, IntPtr wParam,
 * IntPtr lParam, ref bool handled)`: on WM_WINDOWPOSCHANGING the WINDOWPOS behind lParam gets the
 * off-screen target as its x and y, with SWP_NOMOVE cleared, so the window is never put anywhere else.
 * cx, cy and every other message are left alone, and `handled` is never set. It is a window procedure:
 * it does no more than a few reads and writes, and never throws (the first failure goes to stderr, once).
 * WINDOWPOS: hwnd, hwndInsertAfter (pointers), x, y, cx, cy (int), flags (uint).
 */
@:native("HaxeUICs.OffScreenHook")
@:nativeGen
class OffScreenHook {
	public static var X:Int = 0;
	public static var Y:Int = 0;
	static var Failed = false;

	static inline var WM_WINDOWPOSCHANGING:UInt = 0x0046;
	static inline var SWP_NOMOVE = 0x0002;

	public static function Proc(hWnd:IntPtr, msg:UInt, wParam:IntPtr, lParam:IntPtr, handled:cs.Ref<Bool>):IntPtr {
		if (msg == WM_WINDOWPOSCHANGING && lParam != IntPtr.Zero) {
			try {
				var at = 2 * IntPtr.Size;
				Marshal.WriteInt32(lParam, at, X);
				Marshal.WriteInt32(lParam, at + 4, Y);
				var flags = at + 16;
				Marshal.WriteInt32(lParam, flags, Marshal.ReadInt32(lParam, flags) & ~SWP_NOMOVE);
			} catch (e:Dynamic) {
				if (!Failed) {
					Failed = true; // the first failure only, never one per message
					Console.Error.WriteLine("AppDriver: the off-screen hook failed, the window may be on a display: " + e);
				}
			}
		}
		return IntPtr.Zero;
	}
}
#end
