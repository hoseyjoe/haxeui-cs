using System.Collections.Generic;
using System.Runtime.CompilerServices;
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace HaxeUICs
{
    /// <summary>Something painted under a colour-filtered panel: it maps its own colours and bitmaps.</summary>
    public interface IColorFiltered
    {
        /// <param name="matrix">The effective matrix from every filtered ancestor, or null for none.</param>
        void SetEffectiveColorMatrix(float[] matrix);
    }

    /// <summary>
    /// CSS colour filters (grayscale, tint, brightness...) as 4x5 colour matrices, row-major as SVG's
    /// feColorMatrix: R' = m0 R + m1 G + m2 B + m3 A + m4, with channels and offsets in 0..1.
    /// Avalonia 12 has no colour-matrix effect for a subtree, so each painted thing under a filtered
    /// panel maps its own colours and pixels through the effective matrix at paint time.
    /// </summary>
    public static class ColorMatrix
    {
        public static uint Apply(float[] m, uint argb)
        {
            if (m == null) return argb;
            double a = ((argb >> 24) & 0xFF) / 255.0, r = ((argb >> 16) & 0xFF) / 255.0, g = ((argb >> 8) & 0xFF) / 255.0, b = (argb & 0xFF) / 255.0;
            return Pack(
                m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19],
                m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4],
                m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9],
                m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]);
        }

        public static Color Apply(float[] m, Color color) => m == null ? color : Color.FromUInt32(Apply(m, color.ToUInt32()));

        /// <summary>The matrix that applies `inner` first, then `outer`; either may be null.</summary>
        public static float[] Compose(float[] outer, float[] inner)
        {
            if (outer == null) return inner;
            if (inner == null) return outer;
            var result = new float[20];
            for (var row = 0; row < 4; row++)
            {
                for (var col = 0; col < 5; col++)
                {
                    double sum = col == 4 ? outer[row * 5 + 4] : 0; // the outer offset, applied after
                    for (var k = 0; k < 4; k++) sum += outer[row * 5 + k] * inner[k * 5 + col];
                    result[row * 5 + col] = (float)sum;
                }
            }
            return result;
        }

        /// <summary>A brush with its colours mapped; the same brush when there is no matrix.</summary>
        public static IBrush Brush(IBrush brush, float[] m)
        {
            if (m == null || brush == null) return brush;
            switch (brush)
            {
                case ISolidColorBrush solid:
                    return new SolidColorBrush(Apply(m, solid.Color), solid.Opacity);
                case ILinearGradientBrush linear:
                    var stops = new GradientStops();
                    foreach (var stop in linear.GradientStops) stops.Add(new GradientStop(Apply(m, stop.Color), stop.Offset));
                    return new LinearGradientBrush { StartPoint = linear.StartPoint, EndPoint = linear.EndPoint, GradientStops = stops, Opacity = linear.Opacity };
                default:
                    return brush;
            }
        }

        static readonly ConditionalWeakTable<Bitmap, Dictionary<string, Bitmap>> _filtered = new ConditionalWeakTable<Bitmap, Dictionary<string, Bitmap>>();

        /// <summary>Forgets the filtered copies of a bitmap whose pixels were changed in place.</summary>
        public static void Forget(Bitmap source)
        {
            if (source != null) _filtered.Remove(source);
        }

        /// <summary>The bitmap with every pixel mapped (cached per bitmap and matrix); itself with no matrix.</summary>
        public static Bitmap Filter(Bitmap source, float[] m)
        {
            if (m == null || source == null) return source;
            var key = string.Join(",", m);
            var cache = _filtered.GetOrCreateValue(source);
            if (cache.TryGetValue(key, out var done)) return done;
            var size = source.PixelSize;
            var result = new WriteableBitmap(size, source.Dpi, PixelFormat.Bgra8888, AlphaFormat.Unpremul);
            using (var buffer = result.Lock())
            {
                source.CopyPixels(buffer); // converted to the buffer's own format: straight BGRA
                var bytes = new byte[buffer.RowBytes * size.Height];
                System.Runtime.InteropServices.Marshal.Copy(buffer.Address, bytes, 0, bytes.Length);
                for (var y = 0; y < size.Height; y++)
                {
                    for (var x = 0; x < size.Width; x++)
                    {
                        var i = y * buffer.RowBytes + x * 4;
                        var argb = ((uint)bytes[i + 3] << 24) | ((uint)bytes[i + 2] << 16) | ((uint)bytes[i + 1] << 8) | bytes[i];
                        argb = Apply(m, argb);
                        bytes[i] = (byte)argb;
                        bytes[i + 1] = (byte)(argb >> 8);
                        bytes[i + 2] = (byte)(argb >> 16);
                        bytes[i + 3] = (byte)(argb >> 24);
                    }
                }
                System.Runtime.InteropServices.Marshal.Copy(bytes, 0, buffer.Address, bytes.Length);
            }
            cache[key] = result;
            return result;
        }

        static uint Pack(double a, double r, double g, double b)
        {
            return ((uint)Channel(a) << 24) | ((uint)Channel(r) << 16) | ((uint)Channel(g) << 8) | Channel(b);
        }

        static uint Channel(double v) => (uint)System.Math.Round(System.Math.Clamp(v, 0, 1) * 255);
    }
}
