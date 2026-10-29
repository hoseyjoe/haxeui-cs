package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.UIClipboard;

/**
 * The system clipboard's text, answered at once as Heaps' `hxd.System.setClipboardText` and
 * `getClipboardText` are. Each call waits for the OS (at most two seconds, when another program
 * holds the clipboard open), and the window keeps painting meanwhile. Before the window exists
 * there is no clipboard: `setText` and `clear` answer false, `getText` null.
 */
class Clipboard {
	/**
	 * False if the text could not be put on the clipboard. `sensitive` text (a password) is kept
	 * out of Windows' clipboard history (Win+V), its cloud clipboard and clipboard monitors, as
	 * KeePass keeps it; elsewhere it is copied as any text.
	 */
	public static function setText(text:String, sensitive:Bool = false):Bool {
		return UIClipboard.SetText(text, sensitive);
	}

	/** The clipboard's text, or null when it holds none or can't be read. **/
	public static function getText():Null<String> {
		return UIClipboard.GetText();
	}

	/** Empties the clipboard (every format, not only text): a copied secret is gone, not replaced by "". **/
	public static function clear():Bool {
		return UIClipboard.Clear();
	}
}
