using System.IO;

namespace HaxeUICs
{
    /// <summary>
    /// A document picked through Android's file picker, copied into the app's private storage so it
    /// has a real path: the picker hands back a content URI that sys.io.File cannot open, and that
    /// may not outlive the pick. The rules are heaps-android's (MainActivity.kt importDocument), so a
    /// book picked under either backend lands under the same name.
    /// </summary>
    public static class PickedFiles
    {
        /// <summary>
        /// Copies the document into `dir` under its display name and returns the copy's absolute path.
        /// The same book picked again (a file of that name, or a suffixed one, with the same length)
        /// is not copied twice; another book with the same name goes to `Book (2).epub` and on. A
        /// `size` below 0 is unknown and can't be matched, so it always gets a fresh name. Throws
        /// IOException on failure, leaving nothing behind.
        /// </summary>
        public static string Import(string dir, string displayName, long size, System.Func<Stream> open)
        {
            Directory.CreateDirectory(dir);
            var name = SanitiseName(displayName);
            var n = 1;
            var dest = Candidate(dir, name, n);
            while (File.Exists(dest) || Directory.Exists(dest))
            {
                if (size >= 0 && File.Exists(dest) && new FileInfo(dest).Length == size) return Path.GetFullPath(dest);
                n++;
                dest = Candidate(dir, name, n);
            }

            // Written to .part and renamed, so a half-written book is never left under a name the
            // app will try to open.
            var part = dest + ".part";
            try
            {
                using (var input = open())
                {
                    if (input == null) throw new IOException("Could not read the picked file");
                    using (var output = File.Create(part)) input.CopyTo(output);
                }
                File.Move(part, dest);
            }
            catch (IOException)
            {
                TryDelete(part);
                throw;
            }
            catch (System.Exception e)
            {
                TryDelete(part);
                throw new IOException(e.Message, e);
            }
            return Path.GetFullPath(dest);
        }

        /// <summary>
        /// Import from bytes. `knownSize` false imports as a provider that reports no size does;
        /// `failAfter` (-1: never) makes the read fail after that many bytes, as a provider can.
        /// </summary>
        public static string ImportBytes(string dir, string displayName, byte[] bytes, bool knownSize, int failAfter)
        {
            return Import(dir, displayName, knownSize ? bytes.Length : -1, () => new FailingStream(bytes, failAfter));
        }

        /// <summary>A provider's display name is not a filename: it can be absent, and it can contain separators.</summary>
        static string SanitiseName(string displayName)
        {
            var cleaned = (displayName ?? "").Trim().Replace('/', '_').Replace('\\', '_');
            return cleaned == "" || cleaned == "." || cleaned == ".."
                ? "picked-" + System.DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
                : cleaned;
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
