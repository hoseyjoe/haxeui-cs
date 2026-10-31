package haxe.ui.backend.cs.net;

import cs.system.Action;
import cs.system.EventHandler;
import cs.system.Nullable_1;
import cs.system.TimeSpan;

/** Externs for `Avalonia.Threading`, written by hand as hxc binds them. */
@:native("Avalonia.Threading.DispatcherPriority")
@:struct
extern class DispatcherPriority {
	static var Default(default, never):DispatcherPriority;
	static var Normal(default, never):DispatcherPriority;
	static var Send(default, never):DispatcherPriority;
	static var SystemIdle(default, never):DispatcherPriority;
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
	function RunJobs(priority:Nullable_1<DispatcherPriority>):Void;
	function MainLoop(token:cs.system.threading.CancellationToken):Void;
}

@:native("Avalonia.Threading.DispatcherTimer")
extern class DispatcherTimer {
	@:overload function new(interval:TimeSpan, priority:DispatcherPriority, callback:EventHandler);
	var Interval:TimeSpan;
	var IsEnabled:Bool;
	function Start():Void;
	function Stop():Void;
}
