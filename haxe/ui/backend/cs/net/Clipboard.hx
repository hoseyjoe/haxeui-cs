package haxe.ui.backend.cs.net;

import cs.NativeArray;
import cs.types.UInt8;
import haxe.ui.backend.cs.net.Net;

/** Externs for Avalonia's clipboard and data transfer, written by hand as hxc binds them. */
@:native("Avalonia.Input.DataFormat")
extern class DataFormat {
	static var Text(default, never):DataFormat_1<String>;
	static function CreateBytesPlatformFormat(name:String):DataFormat_1<NativeArray<UInt8>>;
	@:overload function Equals(other:DataFormat):Bool;
}

@:native("Avalonia.Input.DataFormat`1")
extern class DataFormat_1<T> extends DataFormat {}

@:native("Avalonia.Input.IAsyncDataTransfer")
extern interface IAsyncDataTransfer {}

@:native("Avalonia.Input.DataTransferItem")
extern class DataTransferItem {
	function new();
	function SetText(text:String):Void;
	@:overload function Set<T>(format:DataFormat_1<T>, value:T):Void;
}

@:native("Avalonia.Input.DataTransfer")
extern class DataTransfer implements IAsyncDataTransfer {
	function new();
	function Add(item:DataTransferItem):Void;
}

@:native("Avalonia.Input.Platform.IClipboard")
extern interface IClipboard {
	function ClearAsync():Task;
	function SetDataAsync(data:IAsyncDataTransfer):Task;
	function FlushAsync():Task;
}

@:native("Avalonia.Input.Platform.ClipboardExtensions")
extern class ClipboardExtensions {
	static function GetDataFormatsAsync(clipboard:IClipboard):Task_1<IReadOnlyList<DataFormat>>;
	static function TryGetTextAsync(clipboard:IClipboard):Task_1<String>;
	static function TryGetValueAsync<T>(clipboard:IClipboard, format:DataFormat_1<T>):Task_1<T>;
}
