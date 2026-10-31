package haxe.ui.backend.cs.native.impl;

import cs.system.Char;
import cs.system.EventHandler_1;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Net;

/** Bit flags naming the input events a listener wants; mirrored by haxe.ui.backend.cs.EventMapper. */
class EventKind {
	public static inline var MOVE = 1;
	public static inline var OVER = 2;
	public static inline var OUT = 4;
	public static inline var DOWN = 8;
	public static inline var UP = 16;
	public static inline var CLICK = 32;
	public static inline var DBL_CLICK = 64;
	public static inline var WHEEL = 128;
	public static inline var RIGHT_DOWN = 256;
	public static inline var RIGHT_UP = 512;
	public static inline var RIGHT_CLICK = 1024;
	public static inline var MIDDLE_DOWN = 2048;
	public static inline var MIDDLE_UP = 4096;
	public static inline var KEY_DOWN = 8192;
	public static inline var KEY_UP = 16384;
	public static inline var MIDDLE_CLICK = 32768;
	public static inline var KEY_PRESS = 65536;
	public static inline var POINTER = MOVE | OVER | OUT | DOWN | UP | CLICK | DBL_CLICK | WHEEL | RIGHT_DOWN | RIGHT_UP | RIGHT_CLICK | MIDDLE_DOWN | MIDDLE_UP | MIDDLE_CLICK;
}

/**
 * Receives input for a panel (or the whole window). Positions are in window coordinates;
 * nativeEvent is the Avalonia event, which NativeEvents.Cancel can stop from bubbling further.
 */
@:native("HaxeUICs.IPanelListener")
@:nativeGen
interface IPanelListener {
	function OnPointer(kind:Int, screenX:Float, screenY:Float, buttonDown:Bool, ctrl:Bool, shift:Bool, alt:Bool, wheelDelta:Float, nativeEvent:Dynamic):Void;
	function OnKey(kind:Int, keyCode:Int, ctrl:Bool, shift:Bool, alt:Bool, nativeEvent:Dynamic):Void;
}

@:native("HaxeUICs.NativeEvents")
@:nativeGen
class NativeEvents {
	/** HaxeUI's event.cancel(): the event stops here, as DOM stopPropagation does. */
	public static function Cancel(nativeEvent:Dynamic):Void {
		if (Std.isOfType(nativeEvent, ClickState)) {
			(cast nativeEvent : ClickState).Cancelled = true;
		} else if (Std.isOfType(nativeEvent, RoutedEventArgs)) {
			(cast nativeEvent : RoutedEventArgs).Handled = true;
		}
	}
}

/** One click as it bubbles from element to element: cancelling it stops the rest. */
@:native("HaxeUICs.ClickState")
@:nativeGen
class ClickState {
	public final Release:PointerReleasedEventArgs;
	public var Cancelled:Bool;

	public function new(release:PointerReleasedEventArgs, cancelled:Bool) {
		Release = release;
		Cancelled = cancelled;
	}
}

/**
 * Subscribes once to every input event of one element and forwards those its listener wants.
 * Events bubble natively, as in the DOM: each ancestor listening for a kind hears it too.
 */
@:native("HaxeUICs.EventRouter")
@:nativeGen
class EventRouter {
	final _target:Interactive;
	final _handledEventsToo:Bool;
	var _attached = false;
	var _kinds = 0;
	var _listener:IPanelListener;

	// Clicks are made here as a browser makes them: a left press and release inside this
	// element is a click, EVERY time, and the second press inside the double-click time also
	// makes a double click. Avalonia's Tapped is not used: it swallows that second click.
	var _pressedHere = false;
	var _middlePressedHere = false;
	var _pressClickCount = 0;
	static var s_click:ClickState;

	// Set during a press that turned into something else (a long press showing a tooltip):
	// its release makes no click. Cleared by the next press.
	static var s_suppressClick = false;

	static final s_isMac = RuntimeInformation.IsOSPlatform(OSPlatform.OSX);

	/** The press under way makes no CLICK (or DBL_CLICK) when it is released. */
	public static function SuppressNextClick():Void {
		s_suppressClick = true;
	}

	public function new(target:Interactive, handledEventsToo:Bool) {
		_target = target;
		_handledEventsToo = handledEventsToo;
	}

	public function Update(kinds:Int, listener:IPanelListener):Void {
		_kinds = kinds;
		_listener = listener;
		if (kinds != 0 && !_attached) {
			Attach();
		}
	}

	function Attach():Void {
		_attached = true;
		var direct = RoutingStrategies.Direct;
		var bubble:RoutingStrategies = cast((cast RoutingStrategies.Bubble : Int) | (cast direct : Int));
		var moved:EventHandler_1<PointerEventArgs> = function(s:Dynamic, e:PointerEventArgs) {
			Pointer(EventKind.MOVE, e, 0, null, false);
		};
		_target.AddHandler(InputElement.PointerMovedEvent, moved, bubble, _handledEventsToo);
		var entered:EventHandler_1<PointerEventArgs> = function(s:Dynamic, e:PointerEventArgs) {
			Pointer(EventKind.OVER, e, 0, null, false);
		};
		_target.AddHandler(InputElement.PointerEnteredEvent, entered, direct, _handledEventsToo);
		var exited:EventHandler_1<PointerEventArgs> = function(s:Dynamic, e:PointerEventArgs) {
			Pointer(EventKind.OUT, e, 0, null, false);
		};
		_target.AddHandler(InputElement.PointerExitedEvent, exited, direct, _handledEventsToo);
		var pressed:EventHandler_1<PointerPressedEventArgs> = function(s:Dynamic, e:PointerPressedEventArgs) {
			Pointer(PressKind(e), e, 0, null, false);
		};
		_target.AddHandler(InputElement.PointerPressedEvent, pressed, bubble, _handledEventsToo);
		var released:EventHandler_1<PointerReleasedEventArgs> = function(s:Dynamic, e:PointerReleasedEventArgs) {
			Pointer(ReleaseKind(e), e, 0, null, false);
		};
		_target.AddHandler(InputElement.PointerReleasedEvent, released, bubble, _handledEventsToo);
		var wheel:EventHandler_1<PointerWheelEventArgs> = function(s:Dynamic, e:PointerWheelEventArgs) {
			Wheel(e);
		};
		_target.AddHandler(InputElement.PointerWheelChangedEvent, wheel, bubble, _handledEventsToo);
		// After the UP handler above, so UP comes before CLICK, as in a browser. Handled events
		// too: a press a component cancelled is still the first half of a click.
		var pressedForClick:EventHandler_1<PointerPressedEventArgs> = function(s:Dynamic, e:PointerPressedEventArgs) {
			PressForClick(e);
		};
		_target.AddHandler(InputElement.PointerPressedEvent, pressedForClick, bubble, true);
		var releasedForClick:EventHandler_1<PointerReleasedEventArgs> = function(s:Dynamic, e:PointerReleasedEventArgs) {
			ReleaseForClick(e);
		};
		_target.AddHandler(InputElement.PointerReleasedEvent, releasedForClick, bubble, true);
		var rightTapped:EventHandler_1<TappedEventArgs> = function(s:Dynamic, e:TappedEventArgs) {
			Tapped(EventKind.RIGHT_CLICK, e);
		};
		_target.AddHandler(InputElement.RightTappedEvent, rightTapped, bubble, _handledEventsToo);
		// Keys always bubble on (a TextBox handles most of them itself), as they do in the DOM.
		var keyDown:EventHandler_1<KeyEventArgs> = function(s:Dynamic, e:KeyEventArgs) {
			KeyEvent(EventKind.KEY_DOWN, e);
		};
		_target.AddHandler(InputElement.KeyDownEvent, keyDown, bubble, true);
		var keyUp:EventHandler_1<KeyEventArgs> = function(s:Dynamic, e:KeyEventArgs) {
			KeyEvent(EventKind.KEY_UP, e);
		};
		_target.AddHandler(InputElement.KeyUpEvent, keyUp, bubble, true);
		// Text the keyboard produces: KEY_PRESS, as heaps maps it (a browser's keypress).
		var textInput:EventHandler_1<TextInputEventArgs> = function(s:Dynamic, e:TextInputEventArgs) {
			KeyPress(e);
		};
		_target.AddHandler(InputElement.TextInputEvent, textInput, bubble, true);
	}

	static inline function HasFlag(modifiers:KeyModifiers, flag:KeyModifiers):Bool {
		return ((cast modifiers : Int) & (cast flag : Int)) != 0;
	}

	function Pointer(kind:Int, e:PointerEventArgs, wheelDelta:Float, nativeEvent:Dynamic, shift:Bool):Void {
		if (kind == 0 || (_kinds & kind) == 0 || _listener == null) {
			return;
		}
		var position = e.GetPosition(Host.Root);
		var properties = e.GetCurrentPoint(null).Properties;
		var modifiers = e.KeyModifiers;
		_listener.OnPointer(kind, position.X, position.Y, properties.IsLeftButtonPressed, KeyCodes.IsCtrl(cast modifiers, s_isMac),
			shift || HasFlag(modifiers, KeyModifiers.Shift), HasFlag(modifiers, KeyModifiers.Alt), Math.max(-1, Math.min(1, wheelDelta)),
			nativeEvent != null ? nativeEvent : e);
		Host.WakeEventsPump(); // a handler may have started a haxe.Timer
	}

	/**
	 * A sideways wheel (or a trackpad's sideways swipe) is shift+wheel, which is how HaxeUI's
	 * ScrollView scrolls across: MouseEvent has no horizontal delta of its own.
	 */
	function Wheel(e:PointerWheelEventArgs):Void {
		if (e.Delta.Y == 0 && e.Delta.X != 0) {
			Pointer(EventKind.WHEEL, e, e.Delta.X, null, true);
		} else {
			Pointer(EventKind.WHEEL, e, e.Delta.Y, null, false);
		}
	}

	function PressForClick(e:PointerPressedEventArgs):Void {
		var kind = e.GetCurrentPoint(null).Properties.PointerUpdateKind;
		if (kind == PointerUpdateKind.MiddleButtonPressed) {
			_middlePressedHere = true;
		}
		if (kind != PointerUpdateKind.LeftButtonPressed) {
			return;
		}
		s_suppressClick = false;
		_pressedHere = true;
		_pressClickCount = e.ClickCount;
	}

	function ReleaseForClick(e:PointerReleasedEventArgs):Void {
		if (e.InitialPressMouseButton == MouseButton.Middle && _middlePressedHere) {
			// a middle press and release inside is a MIDDLE_CLICK, as a left pair is a CLICK
			_middlePressedHere = false;
			if (Inside(e)) {
				Pointer(EventKind.MIDDLE_CLICK, e, 0, null, false);
			}
			return;
		}
		if (e.InitialPressMouseButton != MouseButton.Left || !_pressedHere) {
			return;
		}
		_pressedHere = false;
		if (!Inside(e)) {
			return;
		}
		if (s_click == null || s_click.Release != e) {
			s_click = new ClickState(e, s_suppressClick);
		}
		var click = s_click;
		if (click.Cancelled) {
			return;
		}
		Pointer(EventKind.CLICK, e, 0, click, false);
		if (_pressClickCount == 2 && !click.Cancelled) {
			Pointer(EventKind.DBL_CLICK, e, 0, click, false);
		}
	}

	/** Released over this element (its own hit test, clip included): the click is its. */
	function Inside(e:PointerEventArgs):Bool {
		var p = e.GetPosition(_target);
		if (Std.isOfType(_target, ICustomHitTest)) {
			return (cast _target : ICustomHitTest).HitTest(p);
		}
		var bounds = _target.Bounds;
		return new Rect(0, 0, bounds.Width, bounds.Height).Contains(p);
	}

	function Tapped(kind:Int, e:TappedEventArgs):Void {
		if ((_kinds & kind) == 0 || _listener == null) {
			return;
		}
		var position = e.GetPosition(Host.Root);
		var modifiers = e.KeyModifiers;
		_listener.OnPointer(kind, position.X, position.Y, false, KeyCodes.IsCtrl(cast modifiers, s_isMac),
			HasFlag(modifiers, KeyModifiers.Shift), HasFlag(modifiers, KeyModifiers.Alt), 0, e);
	}

	function KeyEvent(kind:Int, e:KeyEventArgs):Void {
		if ((_kinds & kind) == 0 || _listener == null) {
			return;
		}
		var modifiers = e.KeyModifiers;
		_listener.OnKey(kind, KeyCodes.FromKey(e.Key), KeyCodes.IsCtrl(cast modifiers, s_isMac), HasFlag(modifiers, KeyModifiers.Shift),
			HasFlag(modifiers, KeyModifiers.Alt), e);
		Host.WakeEventsPump();
	}

	function KeyPress(e:TextInputEventArgs):Void {
		var text = e.Text;
		if ((_kinds & EventKind.KEY_PRESS) == 0 || _listener == null || text == null || text == "") {
			return;
		}
		_listener.OnKey(EventKind.KEY_PRESS, Char.ConvertToUtf32(text, 0), false, false, false, e);
	}

	static function PressKind(e:PointerPressedEventArgs):Int {
		var kind = e.GetCurrentPoint(null).Properties.PointerUpdateKind;
		return if (kind == PointerUpdateKind.LeftButtonPressed) {
			EventKind.DOWN;
		} else if (kind == PointerUpdateKind.RightButtonPressed) {
			EventKind.RIGHT_DOWN;
		} else if (kind == PointerUpdateKind.MiddleButtonPressed) {
			EventKind.MIDDLE_DOWN;
		} else {
			0;
		}
	}

	static function ReleaseKind(e:PointerReleasedEventArgs):Int {
		var button = e.InitialPressMouseButton;
		return if (button == MouseButton.Left) {
			EventKind.UP;
		} else if (button == MouseButton.Right) {
			EventKind.RIGHT_UP;
		} else if (button == MouseButton.Middle) {
			EventKind.MIDDLE_UP;
		} else {
			0;
		}
	}
}

/**
 * Avalonia keys as the browser's key codes, which HaxeUI and its apps compare against.
 * Avalonia's own Key values are WPF's enum, not key codes: a key with no browser code is 0.
 */
@:native("HaxeUICs.KeyCodes")
@:nativeGen
class KeyCodes {
	/**
	 * Whether these KeyModifiers (as an int) count as Ctrl. On a Mac, Cmd does: HaxeUI's
	 * KeyboardEvent has no meta key, and an app's Ctrl shortcuts are Cmd shortcuts there.
	 */
	public static function IsCtrl(modifiers:Int, isMac:Bool):Bool {
		return (modifiers & (cast KeyModifiers.Control : Int)) != 0 || (isMac && (modifiers & (cast KeyModifiers.Meta : Int)) != 0);
	}

	/** Where a key falls in a run of the enum, as an offset, or -1. */
	static inline function Offset(key:Key, first:Key, last:Key):Int {
		var at = (cast key : Int) - (cast first : Int);
		return at >= 0 && (cast key : Int) <= (cast last : Int) ? at : -1;
	}

	public static function FromKey(key:Key):Int {
		var at = Offset(key, Key.A, Key.Z);
		if (at >= 0) {
			return 65 + at;
		}
		at = Offset(key, Key.D0, Key.D9);
		if (at >= 0) {
			return 48 + at;
		}
		at = Offset(key, Key.NumPad0, Key.NumPad9);
		if (at >= 0) {
			return 96 + at;
		}
		at = Offset(key, Key.F1, Key.F24);
		if (at >= 0) {
			return 112 + at;
		}
		return switch (key) {
			case Key.Cancel: 3;
			case Key.Back: 8;
			case Key.Tab: 9;
			case Key.Clear: 12;
			case Key.Enter: 13;
			case Key.LeftShift | Key.RightShift: 16;
			case Key.LeftCtrl | Key.RightCtrl: 17;
			case Key.LeftAlt | Key.RightAlt: 18;
			case Key.Pause: 19;
			case Key.CapsLock: 20;
			case Key.KanaMode: 21;
			case Key.JunjaMode: 23;
			case Key.FinalMode: 24;
			case Key.HanjaMode: 25;
			case Key.Escape: 27;
			case Key.ImeConvert: 28;
			case Key.ImeNonConvert: 29;
			case Key.ImeAccept: 30;
			case Key.ImeModeChange: 31;
			case Key.Space: 32;
			case Key.PageUp: 33;
			case Key.PageDown: 34;
			case Key.End: 35;
			case Key.Home: 36;
			case Key.Left: 37;
			case Key.Up: 38;
			case Key.Right: 39;
			case Key.Down: 40;
			case Key.Select: 41;
			case Key.Print: 42;
			case Key.Execute: 43;
			case Key.PrintScreen: 44;
			case Key.Insert: 45;
			case Key.Delete: 46;
			case Key.Help: 47;
			case Key.LWin: 91;
			case Key.RWin: 92;
			case Key.Apps: 93;
			case Key.Sleep: 95;
			case Key.Multiply: 106;
			case Key.Add: 107;
			case Key.Separator: 108;
			case Key.Subtract: 109;
			case Key.Decimal: 110;
			case Key.Divide: 111;
			case Key.NumLock: 144;
			case Key.Scroll: 145;
			case Key.BrowserBack: 166;
			case Key.BrowserForward: 167;
			case Key.BrowserRefresh: 168;
			case Key.BrowserStop: 169;
			case Key.BrowserSearch: 170;
			case Key.BrowserFavorites: 171;
			case Key.BrowserHome: 172;
			case Key.VolumeMute: 173;
			case Key.VolumeDown: 174;
			case Key.VolumeUp: 175;
			case Key.MediaNextTrack: 176;
			case Key.MediaPreviousTrack: 177;
			case Key.MediaStop: 178;
			case Key.MediaPlayPause: 179;
			case Key.LaunchMail: 180;
			case Key.SelectMedia: 181;
			case Key.LaunchApplication1: 182;
			case Key.LaunchApplication2: 183;
			case Key.OemSemicolon: 186;
			case Key.OemPlus: 187;
			case Key.OemComma: 188;
			case Key.OemMinus: 189;
			case Key.OemPeriod: 190;
			case Key.OemQuestion: 191;
			case Key.OemTilde: 192;
			case Key.AbntC1: 193;
			case Key.AbntC2: 194;
			case Key.OemOpenBrackets: 219;
			case Key.OemPipe: 220;
			case Key.OemCloseBrackets: 221;
			case Key.OemQuotes: 222;
			case Key.Oem8: 223;
			case Key.OemBackslash: 226;
			case Key.ImeProcessed: 229;
			case Key.Attn: 246;
			case Key.CrSel: 247;
			case Key.ExSel: 248;
			case Key.EraseEof: 249;
			case Key.Play: 250;
			case Key.Zoom: 251;
			case Key.Pa1: 253;
			case Key.OemClear: 254;
			default: 0;
		}
	}
}
