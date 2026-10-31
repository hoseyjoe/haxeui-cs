package haxe.ui.backend.cs.net;

import cs.system.EventArgs;

/** Externs for `Avalonia.Input` and routed events' arguments, written by hand as hxc binds them. */
@:native("Avalonia.Interactivity.RoutedEventArgs")
extern class RoutedEventArgs extends EventArgs {
	var Handled:Bool;
}

@:native("Avalonia.Input.FocusChangedEventArgs")
extern class FocusChangedEventArgs extends RoutedEventArgs {}

@:native("Avalonia.Input.PointerPressedEventArgs")
extern class PointerPressedEventArgs extends RoutedEventArgs {}

@:native("Avalonia.Input.PointerReleasedEventArgs")
extern class PointerReleasedEventArgs extends RoutedEventArgs {}

@:native("Avalonia.Input.NavigationMethod")
extern enum NavigationMethod {
	Unspecified;
}

@:native("Avalonia.Input.KeyModifiers")
extern enum KeyModifiers {
	None;
}

@:native("Avalonia.Input.IInputElement")
extern interface IInputElement {}

@:native("Avalonia.Input.IFocusManager")
extern interface IFocusManager {
	function Focus(element:IInputElement, method:NavigationMethod, keyModifiers:KeyModifiers):Bool;
}
