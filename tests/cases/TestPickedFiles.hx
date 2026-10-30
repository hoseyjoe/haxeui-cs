package cases;

import haxe.io.Bytes;
import haxe.io.Path;
import haxe.ui.backend.cs.native.Native;
import sys.FileSystem;
import sys.io.File;
import utest.Assert;

/** A picked Android document copied into private storage, by heaps-android's rules (PickedFiles.cs). **/
class TestPickedFiles extends utest.Test {
	function testImportsUnderDisplayName() {
		var dir = freshDir("name");
		var path = importText(dir, "Book.epub", "abc");
		Assert.equals(Path.join([dir, "Book.epub"]), norm(path));
		Assert.equals("abc", File.getContent(path));
	}

	function testSameBookTwiceReusesCopy() {
		var dir = freshDir("twice");
		var first = importText(dir, "Book.epub", "abc");
		var second = importText(dir, "Book.epub", "abc");
		Assert.equals(first, second);
		Assert.equals(1, FileSystem.readDirectory(dir).length);
	}

	function testDifferentBookSameNameGetsSuffix() {
		var dir = freshDir("suffix");
		importText(dir, "Book.epub", "abc");
		Assert.equals(Path.join([dir, "Book (2).epub"]), norm(importText(dir, "Book.epub", "abcd")));
	}

	function testWalksPastSuffixes() {
		var dir = freshDir("walk");
		importText(dir, "Book.epub", "abc");
		var second = importText(dir, "Book.epub", "abcd");
		var third = importText(dir, "Book.epub", "abcd");
		var fourth = importText(dir, "Book.epub", "abcde");
		Assert.equals(second, third);
		Assert.equals(Path.join([dir, "Book (3).epub"]), norm(fourth));
	}

	function testUnknownSizeAlwaysFreshSlot() {
		var dir = freshDir("unknown");
		Assert.equals(Path.join([dir, "Book.epub"]), norm(importText(dir, "Book.epub", "abc", false)));
		Assert.equals(Path.join([dir, "Book (2).epub"]), norm(importText(dir, "Book.epub", "abc", false)));
	}

	function testNoExtension() {
		var dir = freshDir("noext");
		Assert.equals(Path.join([dir, "README"]), norm(importText(dir, "README", "a")));
		Assert.equals(Path.join([dir, "README (2)"]), norm(importText(dir, "README", "ab")));
		importText(dir, ".hidden", "a");
		Assert.equals(Path.join([dir, ".hidden (2)"]), norm(importText(dir, ".hidden", "ab")));
	}

	function testSeparatorsAndEmptyNames() {
		var dir = freshDir("names");
		Assert.equals(Path.join([dir, "a_b_c.epub"]), norm(importText(dir, " a/b\\c.epub ", "a")));
		for (name in ["", ".", ".."]) {
			var file = Path.withoutDirectory(norm(importText(dir, name, "x" + name)));
			Assert.isTrue(StringTools.startsWith(file, "picked-"), '"$name" became "$file"');
		}
	}

	function testFailedCopyLeavesNothing() {
		var dir = freshDir("failed");
		var threw = false;
		try {
			PickedFiles.ImportBytes(dir, "Book.epub", Bytes.ofString("abcdef").getData(), true, 2);
		} catch (e:Dynamic) {
			threw = true;
		}
		Assert.isTrue(threw);
		Assert.equals(0, FileSystem.readDirectory(dir).length);
	}

	function testStreamEndingEarlyIsAFailure() {
		// Some cloud providers end the stream without an error: a short copy must not pass for the book.
		var dir = freshDir("short");
		var threw = false;
		try {
			PickedFiles.ImportCut(dir, "Book.epub", Bytes.ofString("abcdef").getData(), 2);
		} catch (e:Dynamic) {
			threw = true;
		}
		Assert.isTrue(threw);
		Assert.equals(0, FileSystem.readDirectory(dir).length);
	}

	function testAnyFailureIsAnIOException() {
		// FileDialogs answers an IOException with a message box. "" is no directory at all, which
		// .NET refuses with an ArgumentException before any copy starts.
		var thrown:Dynamic = null;
		try {
			importText("", "Book.epub", "abc");
		} catch (e:Dynamic) {
			thrown = e;
		}
		Assert.isTrue(Std.isOfType(thrown, cs.system.io.IOException), 'threw $thrown');
	}

	function testLongNameIsCutToFit() {
		var dir = freshDir("long");
		var path = importText(dir, repeat("a", 300) + ".epub", "abc");
		var file = Path.withoutDirectory(norm(path));
		Assert.isTrue(StringTools.endsWith(file, ".epub"), file);
		Assert.isTrue(utf8Length(file) <= 237, '${utf8Length(file)} bytes');
		Assert.equals("abc", File.getContent(path));
	}

	function testLongNameInBytesIsCutToFit() {
		// Android's limit is 255 bytes, and these are 3 each: 100 fit in 255 UTF-16 units, not in ext4.
		var dir = freshDir("longbytes");
		var file = Path.withoutDirectory(norm(importText(dir, repeat("書", 100) + ".epub", "abc")));
		Assert.isTrue(StringTools.endsWith(file, ".epub"), file);
		Assert.isTrue(utf8Length(file) <= 237, '${utf8Length(file)} bytes');
	}

	function testCutNeverSplitsACharacter() {
		// 4 UTF-8 bytes and 2 UTF-16 units each: "a" puts every boundary off the byte budget.
		var dir = freshDir("longemoji");
		var file = Path.withoutDirectory(norm(importText(dir, "a" + repeat("😀", 80) + ".epub", "abc")));
		Assert.isTrue(utf8Length(file) <= 237, '${utf8Length(file)} bytes');
	}

	function testLongNameKeepsTheDedupeAndSuffixRules() {
		var dir = freshDir("longagain");
		var name = repeat("a", 300) + ".epub";
		var first = importText(dir, name, "abc");
		Assert.equals(first, importText(dir, name, "abc"));
		var other = Path.withoutDirectory(norm(importText(dir, name, "abcd")));
		Assert.isTrue(StringTools.endsWith(other, " (2).epub"), other);
		Assert.equals(2, FileSystem.readDirectory(dir).length);
	}

	function testStaleCopyIsSweptAndARunningOneKept() {
		// A process killed during a copy leaves its temporary behind, under a name nothing picks again.
		var dir = freshDir("sweep");
		var stale = Path.join([dir, "Old.epub.importing"]);
		var running = Path.join([dir, "New.epub.importing"]);
		File.saveContent(stale, "x");
		File.saveContent(running, "x");
		cs.Syntax.code("System.IO.File.SetLastWriteTimeUtc({0}, System.DateTime.UtcNow.AddHours(-2))", stale);
		importText(dir, "Book.epub", "abc");
		Assert.isFalse(FileSystem.exists(stale));
		Assert.isTrue(FileSystem.exists(running));
	}

	static function repeat(s:String, n:Int):String {
		var out = "";
		for (_ in 0...n) out += s;
		return out;
	}

	/** Strict, so a split surrogate pair throws rather than counting as a replacement character. **/
	static function utf8Length(s:String):Int {
		return cs.Syntax.code("new System.Text.UTF8Encoding(false, true).GetByteCount({0})", s);
	}

	static function importText(dir:String, name:String, text:String, knownSize:Bool = true):String {
		return PickedFiles.ImportBytes(dir, name, Bytes.ofString(text).getData(), knownSize, -1);
	}

	static function norm(path:String):String {
		return Path.normalize(path);
	}

	/** A new, empty folder under tests/bin for one test, as an absolute, normalised path. **/
	static function freshDir(name:String):String {
		var dir = Path.normalize(FileSystem.absolutePath("tests/bin/picked-" + name));
		if (FileSystem.exists(dir)) {
			for (f in FileSystem.readDirectory(dir)) FileSystem.deleteFile(Path.join([dir, f]));
		} else {
			FileSystem.createDirectory(dir);
		}
		return dir;
	}
}
