using System.IO;

namespace HaxeUICs
{
    /// <summary>
    /// A document picked through Android's file picker, copied into the app's private storage so it
    /// has a real path: the picker hands back a content URI that sys.io.File cannot open, and that
    /// may not outlive the pick. The rules are heaps-android's (PickedFiles.kt), so a book picked
    /// under either backend lands under the same name.
    /// </summary>
    public static class PickedFiles
    {
        const string PartSuffix = ".importing";

        /// <summary>
        /// ext4's limit on a name is 255 bytes, less what is added to one: the temporary's suffix and
        /// ` (99999)`.
        /// </summary>
        const int MaxNameBytes = 255 - 10 - 8;

        /// <summary>The longest extension kept when a name is cut; anything longer isn't one.</summary>
        const int MaxExtensionBytes = 32;

        /// <summary>
        /// Copies the document into `dir` under its display name and returns the copy's absolute path.
        /// The same book picked again (a file of that name, or a suffixed one, with the same length)
        /// is not copied twice; another book with the same name goes to `Book (2).epub` and on. A
        /// `size` below 0 is unknown and can't be matched, so it always gets a fresh name. Any failure
        /// is an IOException, leaving nothing behind.
        /// </summary>
        public static string Import(string dir, string displayName, long size, System.Func<Stream> open)
        {
            string part = null;
            try
            {
                Directory.CreateDirectory(dir);
                SweepStale(dir);
                var name = FitName(SanitiseName(displayName));
                var n = 1;
                var dest = Candidate(dir, name, n);
                while (File.Exists(dest) || Directory.Exists(dest))
                {
                    if (size >= 0 && File.Exists(dest) && new FileInfo(dest).Length == size) return Path.GetFullPath(dest);
                    n++;
                    dest = Candidate(dir, name, n);
                }

                // Written to a temporary and renamed, so a half-written book is never left under a
                // name the app will try to open.
                part = dest + PartSuffix;
                using (var input = open())
                {
                    if (input == null) throw new IOException("Could not read the picked file");
                    using (var output = File.Create(part))
                    {
                        input.CopyTo(output);
                        // A provider can end the stream early without an error. Only short counts:
                        // a size that is merely stale still gave a whole book.
                        if (output.Length < size) throw new IOException("The picked file ended early");
                    }
                }
                File.Move(part, dest);
                return Path.GetFullPath(dest);
            }
            catch (IOException)
            {
                if (part != null) TryDelete(part);
                throw;
            }
            catch (System.Exception e)
            {
                if (part != null) TryDelete(part);
                throw new IOException(e.Message, e);
            }
        }

        /// <summary>
        /// Import from bytes. `knownSize` false imports as a provider that reports no size does;
        /// `failAfter` (-1: never) makes the read fail after that many bytes, as a provider can.
        /// </summary>
        public static string ImportBytes(string dir, string displayName, byte[] bytes, bool knownSize, int failAfter)
        {
            return Import(dir, displayName, knownSize ? bytes.Length : -1, () => new FailingStream(bytes, failAfter));
        }

        /// <summary>Import of a document that reports its whole size and ends without an error after `endAfter` bytes.</summary>
        public static string ImportCut(string dir, string displayName, byte[] bytes, int endAfter)
        {
            return Import(dir, displayName, bytes.Length, () => new MemoryStream(bytes, 0, endAfter));
        }

        /// <summary>A provider's display name is not a filename: it can be absent, and it can contain separators.</summary>
        static string SanitiseName(string displayName)
        {
            var cleaned = (displayName ?? "").Trim().Replace('/', '_').Replace('\\', '_');
            return cleaned == "" || cleaned == "." || cleaned == ".."
                ? "picked-" + System.DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
                : cleaned;
        }

        /// <summary>
        /// A name that fits, with its extension kept and no character split. Cut the same way each
        /// time, so the same book picked again still finds its copy.
        /// </summary>
        static string FitName(string name)
        {
            var utf8 = System.Text.Encoding.UTF8;
            if (utf8.GetByteCount(name) <= MaxNameBytes) return name;
            var dot = name.LastIndexOf('.');
            var ext = dot > 0 && utf8.GetByteCount(name.Substring(dot)) <= MaxExtensionBytes ? name.Substring(dot) : "";
            var room = MaxNameBytes - utf8.GetByteCount(ext);
            var used = 0;
            var end = 0;
            foreach (var rune in name.EnumerateRunes())
            {
                if (used + rune.Utf8SequenceLength > room) break;
                used += rune.Utf8SequenceLength;
                end += rune.Utf16SequenceLength;
            }
            return name.Substring(0, end).TrimEnd() + ext;
        }

        /// <summary>
        /// A process killed during a copy leaves its temporary behind, and nothing picks that name
        /// again. Old ones only: a slow copy from before this pick may still be running.
        /// </summary>
        static void SweepStale(string dir)
        {
            var cutoff = System.DateTime.UtcNow.AddHours(-1);
            foreach (var file in Directory.EnumerateFiles(dir, "*" + PartSuffix))
            {
                if (File.GetLastWriteTimeUtc(file) < cutoff) TryDelete(file);
            }
        }

        /// <summary>`Book.epub` for 1, `Book (2).epub` for 2, ... A leading dot is not an extension.</summary>
        static string Candidate(string dir, string name, int n)
        {
            if (n <= 1) return Path.Combine(dir, name);
            var dot = name.LastIndexOf('.');
            var stem = dot > 0 ? name.Substring(0, dot) : name;
            var ext = dot > 0 ? name.Substring(dot) : "";
            return Path.Combine(dir, stem + " (" + n + ")" + ext);
        }

        static void TryDelete(string path)
        {
            try { File.Delete(path); }
            catch (System.Exception) { }
        }

        sealed class FailingStream : MemoryStream
        {
            readonly int _failAfter;

            public FailingStream(byte[] bytes, int failAfter) : base(bytes, false)
            {
                _failAfter = failAfter;
            }

            public override int Read(byte[] buffer, int offset, int count)
            {
                if (_failAfter >= 0)
                {
                    if (Position >= _failAfter) throw new IOException("The picked file stopped reading");
                    count = (int)System.Math.Min(count, _failAfter - Position);
                }
                return base.Read(buffer, offset, count);
            }

            public override int Read(System.Span<byte> buffer)
            {
                var array = new byte[buffer.Length];
                var read = Read(array, 0, array.Length);
                System.MemoryExtensions.AsSpan(array, 0, read).CopyTo(buffer);
                return read;
            }
        }
    }
}
