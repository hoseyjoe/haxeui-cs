package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.Out;
import cs.system.Uri;
import cs.system.io.File;
import cs.system.io.Path;
import cs.system.security.cryptography.SHA256;
import cs.types.UInt8;
import haxe.io.Bytes;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;

/**
 * Fonts HaxeUI names by file: a .ttf/.otf from a Haxe resource or from disk gets a font
 * collection of its own, and is then used by the family reference these methods return
 * ("fonts:haxeuics0#Family Name"), which UIText and UITextInput pass to FontFamily.
 */
@:native("HaxeUICs.UIFonts")
@:nativeGen
class UIFonts {
	static final _families = new Map<String, String>();
	static final _byContent = new Map<String, String>();
	static var _collections = 0;

	/** The family reference for a font in these bytes, or null when they are not a font. */
	public static function FromBytes(key:String, data:NativeArray<UInt8>):String {
		if (key == null || data == null) {
			return null;
		}
		if (_families.exists(key)) {
			return _families.get(key);
		}
		// The same font reached by two names (a resource and a file) is loaded once; any other
		// font gets a collection of its own, so faces with the same family name never collide.
		var sha = SHA256.Create();
		var content = Bytes.ofData(Scope.get(sha, () -> sha.ComputeHash(data))).toHex();
		var family:String = null;
		if (_byContent.exists(content)) {
			family = _byContent.get(content);
		} else {
			try {
				var collectionKey = new Uri("fonts:haxeuics" + _collections);
				var collection = new LoadedFonts(collectionKey);
				var typeface:GlyphTypeface = null;
				// The collection reads glyphs from the stream as text is drawn: it stays open.
				if (collection.Add(new MemoryStream(data, false), typeface)) {
					FontManager.Current.AddFontCollection(collection);
					family = collectionKey.OriginalString + "#" + typeface.FamilyName;
				}
			} catch (e:Dynamic) {
				family = null; // not a font Avalonia can read
			}
			_byContent.set(content, family);
			_collections++;
		}
		_families.set(key, family);
		return family;
	}

	/** The family reference for a font file, or null when it is missing or not a font. */
	public static function FromFile(path:String):String {
		if (path == null || path == "") {
			return null;
		}
		var full:String;
		try {
			full = Path.GetFullPath(path);
		} catch (e:Dynamic) {
			return null;
		}
		if (_families.exists(full)) {
			return _families.get(full);
		}
		if (!File.Exists(full)) {
			_families.set(full, null);
			return null;
		}
		var data:NativeArray<UInt8>;
		try {
			data = File.ReadAllBytes(full);
		} catch (e:Dynamic) {
			return null; // locked or not ours to read: the default family (not remembered, it may free up)
		}
		return FromBytes(full, data);
	}

	/** Underline, strikethrough, both or neither (null). */
	public static function Decorations(underline:Bool, strikethrough:Bool):TextDecorationCollection {
		if (!underline && !strikethrough) {
			return null;
		}
		if (!strikethrough) {
			return TextDecorations.Underline;
		}
		if (!underline) {
			return TextDecorations.Strikethrough;
		}
		var both = new TextDecorationCollection();
		both.AddRange(cast TextDecorations.Underline);
		both.AddRange(cast TextDecorations.Strikethrough);
		return both;
	}

	/**
	 * CSS's generic families as installed fonts, each a fallback list (Windows, macOS, Linux)
	 * Avalonia walks until one is present; the default family is the last resort.
	 */
	static final Generic = [
		"monospace" => new FontFamily("Consolas, Menlo, DejaVu Sans Mono, Liberation Mono, Courier New"),
		"serif" => new FontFamily("Times New Roman, Times, DejaVu Serif, Liberation Serif"),
		"cursive" => new FontFamily("Comic Sans MS, Apple Chancery, URW Chancery L"),
		"sans-serif" => FontFamily.Default,
		"system-ui" => FontFamily.Default
	];

	/** The FontFamily to use for the family HaxeUI names; null or empty is the default. */
	public static function ResolveFamily(name:String):FontFamily {
		if (name == null || name == "") {
			return FontFamily.Default;
		}
		var generic = Generic.get(StringTools.trim(name).toLowerCase());
		return generic != null ? generic : new FontFamily(name);
	}
}

/** The collection that fonts loaded from bytes live in. */
@:native("HaxeUICs.LoadedFonts")
@:nativeGen
class LoadedFonts extends FontCollectionBase {
	final _key:Uri;

	public function new(key:Uri) {
		super();
		_key = key;
	}

	@:property override public function get_Key():Uri {
		return _key;
	}

	public function Add(stream:Stream, typeface:Out<GlyphTypeface>):Bool {
		return TryAddGlyphTypeface(stream, typeface);
	}
}
