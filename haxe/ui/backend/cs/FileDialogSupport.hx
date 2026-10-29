package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.IFileDialogListener;
import haxe.ui.containers.dialogs.Dialogs.FileDialogExtensionInfo;

/** Shared by the open and save dialogs: extension filters, and the native listener. **/
class FileDialogSupport {
	/** Only the file-name part of a suggested save name: a name carrying directories cannot steer the picker. **/
	public static function suggestedName(name:String):String {
		if (name == null) {
			return null;
		}
		var file = haxe.io.Path.withoutDirectory(StringTools.replace(name, "\\", "/"));
		return (file == "" || file == "." || file == "..") ? null : file;
	}

	/** HaxeUI extensions ("lor", ".lor" or "*.lor") as glob patterns, with their labels. **/
	public static function filters(extensions:Array<FileDialogExtensionInfo>):{patterns:cs.NativeArray<String>, names:cs.NativeArray<String>} {
		var list = extensions != null ? extensions.filter(e -> e != null && e.extension != null && e.extension != "") : [];
		var patterns = new cs.NativeArray<String>(list.length);
		var names = new cs.NativeArray<String>(list.length);
		for (i in 0...list.length) {
			var ext = list[i].extension;
			while (StringTools.startsWith(ext, "*") || StringTools.startsWith(ext, ".")) {
				ext = ext.substr(1);
			}
			patterns[i] = "*." + ext;
			names[i] = list[i].label;
		}
		return {patterns: patterns, names: names};
	}
}

class FileDialogListener implements IFileDialogListener {
	var onFiles:Array<String>->Void;
	var onCancelled:Void->Void;
	var onFailed:Null<String->Void>;

	/** `onFailed` (only Android's open dialog reports one) is a cancel when not given. **/
	public function new(onFiles:Array<String>->Void, onCancelled:Void->Void, ?onFailed:String->Void) {
		this.onFiles = onFiles;
		this.onCancelled = onCancelled;
		this.onFailed = onFailed;
	}

	public function OnFiles(paths:cs.NativeArray<String>):Void {
		onFiles([for (i in 0...paths.length) paths[i]]);
	}

	public function OnCancelled():Void {
		onCancelled();
	}

	public function OnFailed(message:String):Void {
		if (onFailed != null) onFailed(message);
		else onCancelled();
	}
}
