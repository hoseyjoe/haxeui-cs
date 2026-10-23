package haxe.ui.backend;

import haxe.io.Path;
import haxe.ui.backend.cs.FileDialogSupport;
import haxe.ui.backend.cs.native.Native.FileDialogs;
import haxe.ui.containers.dialogs.Dialogs.SelectedFileInfo;

class OpenFileDialogImpl extends OpenFileDialogBase {
    public override function show() {
        var filters = FileDialogSupport.filters(options.extensions);
        FileDialogs.OpenFiles(options.title, options.multiple, filters.patterns, filters.names, new FileDialogListener(onFiles, dialogCancelled));
    }

    private function onFiles(paths:Array<String>) {
        var files:Array<SelectedFileInfo> = [];
        for (path in paths) {
            var info:SelectedFileInfo = {
                name: Path.withoutDirectory(path),
                fullPath: path,
                isBinary: options.readAsBinary
            };
            if (options.readContents) {
                if (options.readAsBinary) {
                    info.bytes = sys.io.File.getBytes(path);
                } else {
                    info.text = sys.io.File.getContent(path);
                }
            }
            files.push(info);
        }
        dialogConfirmed(files);
    }
}
