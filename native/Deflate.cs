using System.IO;
using System.IO.Compression;

namespace HaxeUICs
{
    /// <summary>
    /// zlib's compress, for haxe.zip.Compress (macros/NativeCompress.hx): Haxe 4.3's C# std leaves
    /// Compress unimplemented, so nothing built on it (a KDBX or zip writer, a PNG encoder) can run.
    /// </summary>
    public static class Deflate
    {
        /// <summary>
        /// A zlib stream (header, deflate, Adler-32) of the bytes, at zlib's level 0..9 (-1: its
        /// default, 6), as zlib's compress2 makes it.
        /// </summary>
        public static byte[] Run(byte[] data, int offset, int length, int level)
        {
            using var output = new MemoryStream();
            var options = new ZLibCompressionOptions { CompressionLevel = System.Math.Clamp(level, -1, 9) };
            using (var deflater = new ZLibStream(output, options, leaveOpen: true))
                deflater.Write(data, offset, length);
            return output.ToArray();
        }
    }
}
