package cases;

import haxe.ui.backend.cs.native.Native;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.OpenFolderDialog;
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

	function testExtensionsBecomeOneFilterEach() {
		var filters = haxe.ui.backend.cs.FileDialogSupport.filters([
			{extension: "lor", label: "Stories"},
			{extension: "png, .gif,*.jpg", label: "Images"}
		]);
		Assert.equals(2, filters.patterns.length);
		Assert.equals("*.lor", filters.patterns[0]);
		Assert.equals("*.png;*.gif;*.jpg", filters.patterns[1]);
		Assert.equals("Images", filters.names[1]);
	}

	function testFilterOfSeveralKeepsEachPattern() {
		var patterns = new cs.NativeArray<String>(1);
		patterns[0] = "*.png;*.gif";
		var filter = @:privateAccess FileDialogs.Filters(patterns, null)[0];
		var all:haxe.ui.backend.cs.net.Net.IReadOnlyCollection<String> = filter.Patterns; // Count is on the collection, as hxc binds it
		Assert.equals(2, all.Count);
		Assert.equals("*.png", filter.Patterns[0]);
		Assert.equals("*.gif", filter.Patterns[1]);
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

	function testOpenFolder() {
		var dir = sys.FileSystem.absolutePath("tests/bin");
		FileDialogs.TestResponse = answer(dir);
		var button:DialogButton = null;
		var folders:Array<String> = null;
		new OpenFolderDialog({title: "Pick"}, (b, f) -> {
			button = b;
			folders = f;
		}).show();
		TestDriver.pump();
		Assert.isTrue(button == DialogButton.OK);
		Assert.equals(dir, folders != null ? folders[0] : null);
	}

	function testOpenFolderCancel() {
		FileDialogs.TestResponse = new cs.NativeArray<String>(0);
		var button:DialogButton = null;
		new OpenFolderDialog({}, (b, f) -> button = b).show();
		TestDriver.pump();
		Assert.isTrue(button == DialogButton.CANCEL);
	}

	function testDialogListenerThrowsIsReported() {
		// a listener that throws is reported, not left to crash the app from an async method
		var path = sys.FileSystem.absolutePath("tests/bin/dialog-open.txt");
		sys.io.File.saveContent(path, "hello");
		FileDialogs.TestResponse = answer(path);
		var listener = new ThrowingListener();
		FileDialogs.OpenFiles("Open", false, new cs.NativeArray<String>(0), new cs.NativeArray<String>(0), listener);
		TestDriver.pump(2);
		Assert.isTrue(listener.called);
	}

	static function answer(path:String):cs.NativeArray<String> {
		var paths = new cs.NativeArray<String>(1);
		paths[0] = path;
		return paths;
	}
}

private class ThrowingListener implements IFileDialogListener {
	public var called = false;

	public function new() {
	}

	public function OnFiles(paths:cs.NativeArray<String>):Void {
		called = true;
		throw "deliberate failure in a file dialog listener";
	}

	public function OnCancelled():Void {
	}

	public function OnFailed(message:String):Void {
	}
}
