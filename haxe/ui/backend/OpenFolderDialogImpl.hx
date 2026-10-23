package haxe.ui.backend;

import haxe.ui.backend.cs.FileDialogSupport;
import haxe.ui.backend.cs.native.Native.FileDialogs;

/** The OS folder picker, through Avalonia's StorageProvider (core's own just shows an error). **/
class OpenFolderDialogImpl extends OpenFolderDialogBase {
    public override function show() {
        FileDialogs.OpenFolder(options.title, options.multiple, options.defaultPath, new FileDialogListener(dialogConfirmed, dialogCancelled));
    }
}
