package cases;

import haxe.ui.backend.cs.native.Native;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.core.Screen;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** Native open/save dialogs (answered by FileDialogs.TestResponse here), and the window title. **/
class TestDialogs extends utest.Test {
	function teardown() {
		FileDialogs.TestResponse = null;
	}

	function testOpenFileReadsContents() {
		var path = sys.FileSystem.absolutePath("tests/bin/dialog-open.txt");
		sys.io.File.saveContent(path, "hello");
		FileDialogs.TestResponse = answer(path);
		var button:DialogButton = null;
		var files:Array<SelectedFileInfo> = null;
		Dialogs.openFile((b, f) -> {
			button = b;
			files = f;
		}, {readContents: true});
		TestDriver.pump();
		Assert.isTrue(button == DialogButton.OK);
		Assert.equals(1, files.length);
		Assert.equals(path, files[0].fullPath);
		Assert.equals("dialog-open.txt", files[0].name);
		Assert.equals("hello", files[0].text);
	}

	function testOpenFileCancel() {
		FileDialogs.TestResponse = new cs.NativeArray<String>(0);
		var button:DialogButton = null;
		Dialogs.openFile((b, f) -> button = b);
		TestDriver.pump();
		Assert.isTrue(button == DialogButton.CANCEL);
	}

	function testSaveFileWritesContents() {
		var path = sys.FileSystem.absolutePath("tests/bin/dialog-save.txt");
		if (sys.FileSystem.exists(path)) {
			sys.FileSystem.deleteFile(path);
		}
		FileDialogs.TestResponse = answer(path);
		var saved:Null<Bool> = null;
		Dialogs.saveTextFile("Save", null, {name: "dialog-save.txt", text: "saved text"}, (result, fullPath) -> saved = result);
		TestDriver.pump();
		Assert.isTrue(saved);
		Assert.equals("saved text", sys.io.File.getContent(path));
	}

	function testSuggestedSaveNameIsOnlyAFileName() {
		// a suggested name carrying directories ("../") must not steer the picker elsewhere
		Assert.equals("story.lor", haxe.ui.backend.cs.FileDialogSupport.suggestedName("../../elsewhere/story.lor"));
		Assert.equals("story.lor", haxe.ui.backend.cs.FileDialogSupport.suggestedName("C:\\stories\\story.lor"));
		Assert.isNull(haxe.ui.backend.cs.FileDialogSupport.suggestedName(".."));
		Assert.isNull(haxe.ui.backend.cs.FileDialogSupport.suggestedName(null));
	}

	function testScreenTitle() {
		Screen.instance.title = "Joeditor";
		Assert.equals("Joeditor", Host.Title);
		Assert.equals("Joeditor", Screen.instance.title);
	}

	static function answer(path:String):cs.NativeArray<String> {
		var paths = new cs.NativeArray<String>(1);
		paths[0] = path;
		return paths;
	}
}
