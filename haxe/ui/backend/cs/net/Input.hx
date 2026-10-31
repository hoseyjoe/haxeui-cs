package haxe.ui.backend.cs.net;

import cs.system.EventArgs;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls.Visual;

/** Externs for `Avalonia.Input` and routed events' arguments, written by hand as hxc binds them. */
@:native("Avalonia.Interactivity.RoutedEventArgs")
extern class RoutedEventArgs extends EventArgs {
	var Handled:Bool;
}

@:native("Avalonia.Input.FocusChangedEventArgs")
extern class FocusChangedEventArgs extends RoutedEventArgs {}

@:native("Avalonia.Interactivity.RoutedEvent`1")
extern class RoutedEvent_1<T> {}

@:native("Avalonia.Interactivity.RoutingStrategies")
extern enum RoutingStrategies {
	Direct;
	Tunnel;
	Bubble;
}

@:native("Avalonia.Input.PointerUpdateKind")
extern enum PointerUpdateKind {
	LeftButtonPressed;
	MiddleButtonPressed;
	RightButtonPressed;
}

@:native("Avalonia.Input.MouseButton")
extern enum MouseButton {
	Left;
	Right;
	Middle;
}

@:native("Avalonia.Input.PointerPointProperties")
@:struct
extern class PointerPointProperties {
	var IsLeftButtonPressed(default, never):Bool;
	var PointerUpdateKind(default, never):PointerUpdateKind;
}

@:native("Avalonia.Input.PointerPoint")
@:struct
extern class PointerPoint {
	var Properties(default, never):PointerPointProperties;
}

@:native("Avalonia.Input.PointerEventArgs")
extern class PointerEventArgs extends RoutedEventArgs {
	var KeyModifiers(default, never):KeyModifiers;
	function GetPosition(relativeTo:Visual):Point;
	function GetCurrentPoint(relativeTo:Visual):PointerPoint;
}

@:native("Avalonia.Input.PointerPressedEventArgs")
extern class PointerPressedEventArgs extends PointerEventArgs {
	var ClickCount(default, never):Int;
}

@:native("Avalonia.Input.PointerReleasedEventArgs")
extern class PointerReleasedEventArgs extends PointerEventArgs {
	var InitialPressMouseButton(default, never):MouseButton;
}

@:native("Avalonia.Input.PointerWheelEventArgs")
extern class PointerWheelEventArgs extends PointerEventArgs {
	var Delta(default, never):Vector;
}

@:native("Avalonia.Input.TappedEventArgs")
extern class TappedEventArgs extends RoutedEventArgs {
	var KeyModifiers(default, never):KeyModifiers;
	function GetPosition(relativeTo:Visual):Point;
}

@:native("Avalonia.Input.KeyEventArgs")
extern class KeyEventArgs extends RoutedEventArgs {
	var Key(default, never):Key;
	var KeyModifiers(default, never):KeyModifiers;
}

@:native("Avalonia.Input.TextInputEventArgs")
extern class TextInputEventArgs extends RoutedEventArgs {
	var Text(default, never):String;
}

@:native("Avalonia.Input.Key")
extern enum Key {
	A;
	Z;
	D0;
	D9;
	NumPad0;
	NumPad9;
	F1;
	F24;
	Cancel;
	Back;
	Tab;
	Clear;
	Enter;
	LeftShift;
	RightShift;
	LeftCtrl;
	RightCtrl;
	LeftAlt;
	RightAlt;
	Pause;
	CapsLock;
	KanaMode;
	JunjaMode;
	FinalMode;
	HanjaMode;
	Escape;
	ImeConvert;
	ImeNonConvert;
	ImeAccept;
	ImeModeChange;
	Space;
	PageUp;
	PageDown;
	End;
	Home;
	Left;
	Up;
	Right;
	Down;
	Select;
	Print;
	Execute;
	PrintScreen;
	Insert;
	Delete;
	Help;
	LWin;
	RWin;
	Apps;
	Sleep;
	Multiply;
	Add;
	Separator;
	Subtract;
	Decimal;
	Divide;
	NumLock;
	Scroll;
	BrowserBack;
	BrowserForward;
	BrowserRefresh;
	BrowserStop;
	BrowserSearch;
	BrowserFavorites;
	BrowserHome;
	VolumeMute;
	VolumeDown;
	VolumeUp;
	MediaNextTrack;
	MediaPreviousTrack;
	MediaStop;
	MediaPlayPause;
	LaunchMail;
	SelectMedia;
	LaunchApplication1;
	LaunchApplication2;
	OemSemicolon;
	OemPlus;
	OemComma;
	OemMinus;
	OemPeriod;
	OemQuestion;
	OemTilde;
	AbntC1;
	AbntC2;
	OemOpenBrackets;
	OemPipe;
	OemCloseBrackets;
	OemQuotes;
	Oem8;
	OemBackslash;
	ImeProcessed;
	Attn;
	CrSel;
	ExSel;
	EraseEof;
	Play;
	Zoom;
	Pa1;
	OemClear;
}

@:native("Avalonia.Input.NavigationMethod")
extern enum NavigationMethod {
	Unspecified;
}

@:native("Avalonia.Input.KeyModifiers")
extern enum KeyModifiers {
	None;
	Alt;
	Control;
	Shift;
	Meta;
}

@:native("Avalonia.Input.IInputElement")
extern interface IInputElement {}

@:native("Avalonia.Input.IFocusManager")
extern interface IFocusManager {
	function Focus(element:IInputElement, method:NavigationMethod, keyModifiers:KeyModifiers):Bool;
}

@:native("Avalonia.Input.StandardCursorType")
extern enum StandardCursorType {
	Arrow;
	Ibeam;
	Wait;
	Cross;
	UpArrow;
	SizeWestEast;
	SizeNorthSouth;
	SizeAll;
	No;
	Hand;
	AppStarting;
	Help;
	TopSide;
	BottomSide;
	LeftSide;
	RightSide;
	TopLeftCorner;
	TopRightCorner;
	BottomLeftCorner;
	BottomRightCorner;
	DragMove;
	DragCopy;
	DragLink;
	None;
}

@:native("Avalonia.Input.Cursor")
extern class Cursor {
	@:overload function new(cursor:StandardCursorType);
}
