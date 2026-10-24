using System;
using System.Collections.Generic;
using System.IO;
using Avalonia.Media;
using Avalonia.Media.Fonts;

namespace HaxeUICs
{
    /// <summary>
    /// Fonts HaxeUI names by file: a .ttf/.otf from a Haxe resource or from disk gets a font
    /// collection of its own, and is then used by the family reference these methods return
    /// ("fonts:haxeuics0#Family Name"), which UIText and UITextInput pass to FontFamily.
    /// </summary>
    public static class UIFonts
    {
        static readonly Dictionary<string, string> _families = new Dictionary<string, string>();
        static readonly Dictionary<string, string> _byContent = new Dictionary<string, string>();

        /// <summary>The family reference for a font in these bytes, or null when they are not a font.</summary>
        public static string FromBytes(string key, byte[] data)
        {
            if (key == null || data == null) return null;
            if (_families.TryGetValue(key, out var known)) return known;
            // The same font reached by two names (a resource and a file) is loaded once; any other
            // font gets a collection of its own, so faces with the same family name never collide.
            var content = System.Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(data));
            if (!_byContent.TryGetValue(content, out var family))
            {
                family = null;
                try
                {
                    var collectionKey = new Uri("fonts:haxeuics" + _byContent.Count);
                    var collection = new LoadedFonts(collectionKey);
                    // The collection reads glyphs from the stream as text is drawn: it stays open.
                    if (collection.Add(new MemoryStream(data, false), out var typeface))
                    {
                        FontManager.Current.AddFontCollection(collection);
                        family = collectionKey.OriginalString + "#" + typeface.FamilyName;
                    }
                }
                catch (Exception)
                {
                    family = null; // not a font Avalonia can read
                }
                _byContent[content] = family;
            }
            _families[key] = family;
            return family;
        }

        /// <summary>The family reference for a font file, or null when it is missing or not a font.</summary>
        public static string FromFile(string path)
        {
            if (string.IsNullOrEmpty(path)) return null;
            string full;
            try { full = Path.GetFullPath(path); }
            catch (Exception) { return null; }
            if (_families.TryGetValue(full, out var known)) return known;
            if (!File.Exists(full))
            {
                _families[full] = null;
                return null;
            }
            return FromBytes(full, File.ReadAllBytes(full));
        }

        /// <summary>Underline, strikethrough, both or neither (null).</summary>
        public static TextDecorationCollection Decorations(bool underline, bool strikethrough)
        {
            if (!underline && !strikethrough) return null;
            if (!strikethrough) return TextDecorations.Underline;
            if (!underline) return TextDecorations.Strikethrough;
            var both = new TextDecorationCollection();
            both.AddRange(TextDecorations.Underline);
            both.AddRange(TextDecorations.Strikethrough);
            return both;
        }

        /// <summary>The FontFamily to use for the family HaxeUI names; null or empty is the default.</summary>
        public static FontFamily ResolveFamily(string name)
        {
            return string.IsNullOrEmpty(name) ? FontFamily.Default : new FontFamily(name);
        }
    }

    /// <summary>The collection that fonts loaded from bytes live in.</summary>
    class LoadedFonts : FontCollectionBase
    {
        public LoadedFonts(Uri key)
        {
            Key = key;
        }

        public override Uri Key { get; }

        public bool Add(Stream stream, out GlyphTypeface typeface) => TryAddGlyphTypeface(stream, out typeface);
    }
}
