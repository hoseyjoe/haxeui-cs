using System.IO;
using System.IO.Compression;

namespace HaxeUICs
{
    /// <summary>
    /// zlib's inflate, for haxe.zip.Uncompress (macros/NativeUncompress.hx): Haxe 4.3's
    /// C# std leaves Uncompress unimplemented, so no zip, EPUB or PNG reader built on it can run.
    /// </summary>
    public static class Inflate
    {
        /// <summary>
        /// Inflates a whole stream. windowBits reads as zlib reads it: 8..15 a zlib stream, -8..-15
        /// raw deflate (a zip entry), 24..31 gzip, 40..47 zlib or gzip by the stream's own header.
        /// </summary>
        public static byte[] Run(byte[] data, int offset, int length, int windowBits)
        {
            var gzip = windowBits > 31
                ? length >= 2 && data[offset] == 0x1f && data[offset + 1] == 0x8b
                : windowBits > 15;
            using var input = new MemoryStream(data, offset, length, false);
            using Stream inflater = windowBits < 0 ? new DeflateStream(input, CompressionMode.Decompress)
                : gzip ? new GZipStream(input, CompressionMode.Decompress)
                : new ZLibStream(input, CompressionMode.Decompress);
            using var output = new MemoryStream();
            inflater.CopyTo(output);
            return output.ToArray();
        }
    }
}
