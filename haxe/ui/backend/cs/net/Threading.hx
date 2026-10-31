package haxe.ui.backend.cs.net;

import cs.system.Action;

/** Externs for `Avalonia.Threading`, written by hand as hxc binds them. */
@:native("Avalonia.Threading.DispatcherPriority")
@:struct
extern class DispatcherPriority {
	static var Send(default, never):DispatcherPriority;
}

@:native("Avalonia.Threading.DispatcherFrame")
extern class DispatcherFrame {
	@:overload function new();
	var Continue:Bool;
}

@:native("Avalonia.Threading.Dispatcher")
extern class Dispatcher {
	static var UIThread(default, never):Dispatcher;
	@:overload function Post(action:Action, priority:DispatcherPriority):Void;
	function PushFrame(frame:DispatcherFrame):Void;
}
