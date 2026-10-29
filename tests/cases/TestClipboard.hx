package cases;

import haxe.ui.backend.cs.Clipboard;
import haxe.ui.backend.cs.TestDriver;
import utest.Assert;

/** The system clipboard's text (headless: Avalonia's in-memory clipboard). **/
class TestClipboard extends utest.Test {
	function teardown() {
		Clipboard.clear();
	}

	function testRoundTrip() {
		Assert.isTrue(Clipboard.setText("hunter2"));
		Assert.equals("hunter2", Clipboard.getText());
	}

	function testLaterTextReplaces() {
		Clipboard.setText("first");
		Clipboard.setText("second");
		Assert.equals("second", Clipboard.getText());
	}

	function testUnicode() {
		var text = "päss € \u{1F511}\nline two";
		Assert.isTrue(Clipboard.setText(text));
		Assert.equals(text, Clipboard.getText());
	}

	function testClear() {
		Clipboard.setText("secret");
		Assert.isTrue(Clipboard.clear());
		Assert.isNull(Clipboard.getText(), "nothing on the clipboard");
	}

	static final SENSITIVE = [
		"ExcludeClipboardContentFromMonitorProcessing",
		"CanIncludeInClipboardHistory",
		"CanUploadToCloudClipboard"
	];

	function testSensitiveRoundTrip() {
		Assert.isTrue(Clipboard.setText("hunter2", true));
		Assert.equals("hunter2", Clipboard.getText());
	}

	/** Windows' marks beside the text, each a DWORD 0; no other OS has them. **/
	function testSensitiveKeptOutOfHistory() {
		Clipboard.setText("hunter2", true);
		var windows = Sys.systemName() == "Windows";
		for (name in SENSITIVE)
			Assert.equals(windows ? "00000000" : null, TestDriver.clipboardFormat(name), name);
	}

	function testPlainTextHasNoHistoryMarks() {
		Clipboard.setText("hunter2", true);
		Clipboard.setText("plain");
		for (name in SENSITIVE)
			Assert.isNull(TestDriver.clipboardFormat(name), name);
		Assert.equals("plain", Clipboard.getText());
	}

	function testClearRemovesHistoryMarks() {
		Clipboard.setText("hunter2", true);
		Clipboard.clear();
		for (name in SENSITIVE)
			Assert.isNull(TestDriver.clipboardFormat(name), name);
	}

	function testEmptyText() {
		Clipboard.setText("secret");
		Assert.isTrue(Clipboard.setText(""));
		var now = Clipboard.getText();
		Assert.isTrue(now == null || now == "", 'empty, not the old text: $now');
	}
}
