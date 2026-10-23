package haxe.ui.backend;

import haxe.io.Path;
import haxe.ui.backend.cs.FileDialogSupport;
import haxe.ui.backend.cs.native.Native.FileDialogs;

class SaveFileDialogImpl extends SaveFileDialogBase {
    public override function show() {
        var filters = FileDialogSupport.filters(options.extensions);
        var suggested = fileInfo != null ? fileInfo.name : null;
        FileDialogs.SaveFile(options.title, suggested, filters.patterns, filters.names, new FileDialogListener(onFiles, dialogCancelled));
    }

    private function onFiles(paths:Array<String>) {
        var path = paths[0];
        var binary = options.writeAsBinary == true || (fileInfo != null && fileInfo.isBinary == true);
        if (fileInfo != null) {
            if (binary && fileInfo.bytes != null) {
                sys.io.File.saveBytes(path, fileInfo.bytes);
            } else if (fileInfo.text != null) {
                sys.io.File.saveContent(path, fileInfo.text);
            }
        }
        dialogConfirmed({
            name: Path.withoutDirectory(path),
            fullPath: path,
            text: fileInfo != null ? fileInfo.text : null,
            bytes: fileInfo != null ? fileInfo.bytes : null,
            isBinary: binary
        });
    }
}
