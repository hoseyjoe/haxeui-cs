package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Console;
#if haxeui_cs_android
import cs.system.AggregateException;
import cs.system.Exception;
import cs.system.Func_1;
import cs.system.io.Path;
import cs.types.Int64;
#end
import haxe.ui.backend.cs.native.impl.Host.Host;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Storage;

/** What a file dialog tells the HaxeUI side when it closes. */
@:native("HaxeUICs.IFileDialogListener")
@:nativeGen
interface IFileDialogListener {
	function OnFiles(paths:NativeArray<String>):Void;
	function OnCancelled():Void;
	/** The dialog closed on a file that could not be read; the message says why. */
	function OnFailed(message:String):Void;
}

/**
 * The OS open/save file pickers, through Avalonia's StorageProvider. Each step after a picker runs
 * through `Continue` and is wrapped here, so a failure answers the listener as well as being reported.
 */
@:native("HaxeUICs.FileDialogs")
class FileDialogs {
	/**
	 * Tests set this to answer every dialog at once without showing one: the paths chosen, or
	 * an empty array (or one with a null entry) for Cancel. Null shows the real dialog.
	 */
	public static var TestResponse:NativeArray<String>;

	/**
	 * @param patterns Glob patterns such as "*.lor"; empty for any file.
	 * @param patternNames A label for each pattern.
	 */
	public static function OpenFiles(title:String, multiple:Bool, patterns:NativeArray<String>, patternNames:NativeArray<String>,
			listener:IFileDialogListener):Void {
		try {
			if (TestResponse != null) {
				Answer(TestResponse, listener);
				return;
			}
			var storage = Provider();
			if (storage == null || !storage.CanOpen) {
				Cancel(listener);
				return;
			}
			#if haxeui_cs_android
			OpenOnAndroid(storage, title, listener);
			#else
			var options = new FilePickerOpenOptions();
			options.Title = title;
			options.AllowMultiple = multiple;
			options.FileTypeFilter = cast Filters(patterns, patternNames);
			Continue.then(storage.OpenFilePickerAsync(options), function(files:IReadOnlyList<IStorageFile>) {
				Step(listener, function() {
					var paths = [];
					var all:IReadOnlyCollection<IStorageFile> = files; // Count is on the collection, as hxc binds it
					for (i in 0...all.Count) {
						var file:IStorageFile = files[i];
						var path = StorageProviderExtensions.TryGetLocalPath(file);
						if (path != null) {
							paths.push(path);
						}
					}
					Answer(ToNative(paths), listener);
				});
			}, function(e:Dynamic) {
				Abandon(e, listener);
			});
			#end
		} catch (e:Dynamic) {
			Abandon(e, listener);
		}
	}

	public static function SaveFile(title:String, suggestedName:String, patterns:NativeArray<String>, patternNames:NativeArray<String>,
			listener:IFileDialogListener):Void {
		try {
			if (TestResponse != null) {
				Answer(TestResponse, listener);
				return;
			}
			#if haxeui_cs_android
			// Android's picker hands back a content URI, never a path to write to.
			Cancel(listener);
			#else
			var storage = Provider();
			if (storage == null || !storage.CanSave) {
				Cancel(listener);
				return;
			}
			var options = new FilePickerSaveOptions();
			options.Title = title;
			options.SuggestedFileName = suggestedName;
			options.FileTypeChoices = cast Filters(patterns, patternNames);
			Continue.then(storage.SaveFilePickerAsync(options), function(file:IStorageFile) {
				Step(listener, function() {
					var path = file != null ? StorageProviderExtensions.TryGetLocalPath(file) : null;
					Answer(ToNative(path != null ? [path] : []), listener);
				});
			}, function(e:Dynamic) {
				Abandon(e, listener);
			});
			#end
		} catch (e:Dynamic) {
			Abandon(e, listener);
		}
	}

	/** @param defaultPath The folder to start in, or null for the OS's choice. */
	public static function OpenFolder(title:String, multiple:Bool, defaultPath:String, listener:IFileDialogListener):Void {
		try {
			if (TestResponse != null) {
				Answer(TestResponse, listener);
				return;
			}
			#if haxeui_cs_android
			// A picked folder is a content URI tree, never a path the app can list.
			Cancel(listener);
			#else
			var storage = Provider();
			if (storage == null || !storage.CanPickFolder) {
				Cancel(listener);
				return;
			}
			if (defaultPath == null || defaultPath == "") {
				PickFolder(storage, title, multiple, null, listener);
				return;
			}
			Continue.then(StorageProviderExtensions.TryGetFolderFromPathAsync(storage, defaultPath), function(start:IStorageFolder) {
				Step(listener, function() {
					PickFolder(storage, title, multiple, start, listener);
				});
			}, function(e:Dynamic) {
				Abandon(e, listener);
			});
			#end
		} catch (e:Dynamic) {
			Abandon(e, listener);
		}
	}

	static function Provider():IStorageProvider {
		var top = Host.TopLevel;
		return top != null ? top.StorageProvider : null;
	}

	#if !haxeui_cs_android
	static function PickFolder(storage:IStorageProvider, title:String, multiple:Bool, start:IStorageFolder, listener:IFileDialogListener):Void {
		var options = new FolderPickerOpenOptions();
		options.Title = title;
		options.AllowMultiple = multiple;
		options.SuggestedStartLocation = start;
		Continue.then(storage.OpenFolderPickerAsync(options), function(folders:IReadOnlyList<IStorageFolder>) {
			Step(listener, function() {
				var paths = [];
				var all:IReadOnlyCollection<IStorageFolder> = folders; // Count is on the collection, as hxc binds it
				for (i in 0...all.Count) {
					var folder:IStorageFolder = folders[i];
					var path = StorageProviderExtensions.TryGetLocalPath(folder);
					if (path != null) {
						paths.push(path);
					}
				}
				Answer(ToNative(paths), listener);
			});
		}, function(e:Dynamic) {
			Abandon(e, listener);
		});
	}
	#end

	#if haxeui_cs_android
	/**
	 * Android's picker answers with a content URI, not a path: the one file chosen (patterns do
	 * not apply) is copied into the app's files/picked/ by PickedFiles, off the UI thread, and
	 * that copy's path is the answer. Any failure from the picker on is reported to the listener,
	 * which shows it, rather than passing for a cancel.
	 */
	static function OpenOnAndroid(storage:IStorageProvider, title:String, listener:IFileDialogListener):Void {
		var failed = function(e:Dynamic) {
			Report(e);
			Fail(MessageOf(e), listener);
		};
		try {
			var options = new FilePickerOpenOptions();
			options.Title = title;
			options.AllowMultiple = false;
			Continue.then(storage.OpenFilePickerAsync(options), function(files:IReadOnlyList<IStorageFile>) {
				try {
					var all:IReadOnlyCollection<IStorageFile> = files; // Count is on the collection, as hxc binds it
					if (all.Count == 0) {
						Cancel(listener);
						return;
					}
					var file:IStorageFile = files[0];
					Continue.then(file.GetBasicPropertiesAsync(), function(properties:StorageItemProperties) {
						try {
							var size:Int64 = -1;
							if (properties != null && properties.Size.HasValue) {
								size = cast properties.Size.Value;
							}
							var import_:Func_1<String> = function():String {
								var open:Func_1<Stream> = function():Stream {
									return ReadResult(file);
								};
								return PickedFiles.Import(Path.Combine(Host.FilesDir, "picked"), file.Name, size, open);
							};
							Continue.then(Task.Run(import_), function(path:String) {
								Answer(ToNative([path]), listener);
							}, failed);
						} catch (e:Dynamic) {
							failed(e);
						}
					}, failed);
				} catch (e:Dynamic) {
					failed(e);
				}
			}, failed);
		} catch (e:Dynamic) {
			failed(e);
		}
	}

	// `.Result` wraps a failure in AggregateException, where `await` throws the failure itself.
	static function ReadResult(file:IStorageFile):Stream {
		try {
			return file.OpenReadAsync().Result;
		} catch (e:AggregateException) {
			if (e.InnerException != null) {
				throw e.InnerException;
			}
			throw e;
		}
	}

	static function MessageOf(e:Dynamic):String {
		return Std.isOfType(e, Exception) ? (cast e : Exception).Message : Std.string(e);
	}
	#end

	// A step after a picker: anything it throws is a failure of the dialog.
	static function Step(listener:IFileDialogListener, step:Void->Void):Void {
		try {
			step();
		} catch (e:Dynamic) {
			Abandon(e, listener);
		}
	}

	static function Abandon(e:Dynamic, listener:IFileDialogListener):Void {
		Report(e);
		Cancel(listener);
	}

	// These run from the UI thread's callbacks: anything thrown there would reach Avalonia's
	// dispatcher and end the app, so failures are reported instead, never thrown.
	static function Answer(paths:NativeArray<String>, listener:IFileDialogListener):Void {
		if (paths.Length == 0) {
			Cancel(listener);
			return;
		}
		for (i in 0...paths.Length) {
			if (paths[i] == null) {
				Cancel(listener);
				return;
			}
		}
		try {
			listener.OnFiles(paths);
		} catch (e:Dynamic) {
			Report(e);
		}
	}

	static function Cancel(listener:IFileDialogListener):Void {
		try {
			listener.OnCancelled();
		} catch (e:Dynamic) {
			Report(e);
		}
	}

	static function Fail(message:String, listener:IFileDialogListener):Void {
		try {
			listener.OnFailed(message);
		} catch (e:Dynamic) {
			Report(e);
		}
	}

	static function Report(e:Dynamic):Void {
		Console.Error.WriteLine("haxeui-cs: a file dialog failed: " + Std.string(e));
	}

	static function ToNative(paths:Array<String>):NativeArray<String> {
		var native = new NativeArray<String>(paths.length);
		for (i in 0...paths.length) {
			native[i] = paths[i];
		}
		return native;
	}

	static function Filters(patterns:NativeArray<String>, names:NativeArray<String>):NativeArray<FilePickerFileType> {
		if (patterns == null || patterns.Length == 0) {
			return null;
		}
		var filters = new NativeArray<FilePickerFileType>(patterns.Length);
		for (i in 0...patterns.Length) {
			var name = names != null && i < names.Length && names[i] != null && names[i] != "" ? names[i] : patterns[i];
			var filter = new FilePickerFileType(name);
			var one = new NativeArray<String>(1);
			one[0] = patterns[i];
			filter.Patterns = cast one;
			filters[i] = filter;
		}
		return filters;
	}
}
