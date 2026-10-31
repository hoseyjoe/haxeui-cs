package haxe.ui.backend.cs.net;

import cs.system.Nullable_1;
import cs.types.UInt64;
import haxe.ui.backend.cs.net.Net;

/** Externs for `Avalonia.Platform.Storage`, written by hand as hxc binds them. */
@:native("Avalonia.Platform.Storage.StorageItemProperties")
extern class StorageItemProperties {
	var Size(default, never):Nullable_1<UInt64>;
}

@:native("Avalonia.Platform.Storage.IStorageItem")
extern interface IStorageItem {
	var Name(default, never):String;
	function GetBasicPropertiesAsync():Task_1<StorageItemProperties>;
}

@:native("Avalonia.Platform.Storage.IStorageFile")
extern interface IStorageFile extends IStorageItem {
	function OpenReadAsync():Task_1<Stream>;
}

@:native("Avalonia.Platform.Storage.IStorageFolder")
extern interface IStorageFolder extends IStorageItem {}

@:native("Avalonia.Platform.Storage.FilePickerFileType")
extern class FilePickerFileType {
	function new(name:String);
	var Patterns:IReadOnlyList<String>;
}

@:native("Avalonia.Platform.Storage.PickerOptions")
extern class PickerOptions {
	var Title:String;
	var SuggestedStartLocation:IStorageFolder;
	var SuggestedFileName:String;
}

@:native("Avalonia.Platform.Storage.FilePickerOpenOptions")
extern class FilePickerOpenOptions extends PickerOptions {
	function new();
	var AllowMultiple:Bool;
	var FileTypeFilter:IReadOnlyList<FilePickerFileType>;
}

@:native("Avalonia.Platform.Storage.FilePickerSaveOptions")
extern class FilePickerSaveOptions extends PickerOptions {
	function new();
	var FileTypeChoices:IReadOnlyList<FilePickerFileType>;
}

@:native("Avalonia.Platform.Storage.FolderPickerOpenOptions")
extern class FolderPickerOpenOptions extends PickerOptions {
	function new();
	var AllowMultiple:Bool;
}

@:native("Avalonia.Platform.Storage.IStorageProvider")
extern interface IStorageProvider {
	var CanOpen(default, never):Bool;
	var CanSave(default, never):Bool;
	var CanPickFolder(default, never):Bool;
	function OpenFilePickerAsync(options:FilePickerOpenOptions):Task_1<IReadOnlyList<IStorageFile>>;
	function SaveFilePickerAsync(options:FilePickerSaveOptions):Task_1<IStorageFile>;
	function OpenFolderPickerAsync(options:FolderPickerOpenOptions):Task_1<IReadOnlyList<IStorageFolder>>;
}

@:native("Avalonia.Platform.Storage.StorageProviderExtensions")
extern class StorageProviderExtensions {
	static function TryGetFolderFromPathAsync(provider:IStorageProvider, path:String):Task_1<IStorageFolder>;
	static function TryGetLocalPath(item:IStorageItem):String;
}
