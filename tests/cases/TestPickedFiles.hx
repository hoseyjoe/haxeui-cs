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
