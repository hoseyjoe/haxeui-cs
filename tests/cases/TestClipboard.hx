package cases;

import haxe.ui.backend.cs.Clipboard;
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

	function testEmptyText() {
		Clipboard.setText("secret");
		Assert.isTrue(Clipboard.setText(""));
		var now = Clipboard.getText();
		Assert.isTrue(now == null || now == "", 'empty, not the old text: $now');
	}
}
