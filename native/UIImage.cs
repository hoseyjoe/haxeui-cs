using Avalonia.Platform;
using System.Collections.Generic;
using System.IO;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;

namespace HaxeUICs
{
    /// <summary>A decoded image: HaxeUI's ImageData.</summary>
    public class UIImage
    {
        readonly Bitmap _bitmap;
        readonly Svg.Skia.SKSvg _svg; // owns the picture
        readonly SkiaSharp.SKPicture _picture;
        readonly Dictionary<(int, int), Bitmap> _rasters = new Dictionary<(int, int), Bitmap>();
        readonly List<(int, int)> _rasterOrder = new List<(int, int)>();

        /// <summary>
        /// Device pixels per layout unit where a visual draws: the screen's render scaling times any
        /// scale on the way to the window (Toolkit.scale), so vector images are drawn for that size.
        /// </summary>
        public static double DeviceScale(Visual visual)
        {
            var top = TopLevel.GetTopLevel(visual);
            if (top == null) return 1;
            var scale = top.RenderScaling;
            var m = visual.TransformToVisual(top);
            if (m.HasValue) scale *= System.Math.Sqrt(m.Value.M11 * m.Value.M11 + m.Value.M12 * m.Value.M12);
            return scale;
        }

        /// <summary>The image at its own size (a vector image drawn at its intrinsic size).</summary>
        public Bitmap Bitmap => _bitmap ?? BitmapFor(Width, Height);
        public int Width { get; }
        public int Height { get; }
        public bool IsVector => _picture != null;

        /// <summary>How many drawn sizes of a vector image are kept.</summary>
        public int CachedSizes => _rasters.Count;

        UIImage(Bitmap bitmap)
        {
            _bitmap = bitmap;
            Width = bitmap.PixelSize.Width;
            Height = bitmap.PixelSize.Height;
        }

        UIImage(Svg.Skia.SKSvg svg, SkiaSharp.SKPicture picture)
        {
            _svg = svg;
            _picture = picture;
            Width = System.Math.Max(1, (int)System.Math.Ceiling(picture.CullRect.Width));
            Height = System.Math.Max(1, (int)System.Math.Ceiling(picture.CullRect.Height));
        }

        /// <summary>Decodes PNG/JPEG/etc. or SVG bytes; null when they are not an image.</summary>
        public static UIImage FromBytes(byte[] data)
        {
            if (data == null || data.Length == 0) return null;
            if (LooksLikeSvg(data)) return FromSvg(data);
            try
            {
                using var stream = new MemoryStream(data);
                return new UIImage(new Bitmap(stream));
            }
            catch (System.Exception)
            {
                return null;
            }
        }

        static bool LooksLikeSvg(byte[] data)
        {
            var head = System.Text.Encoding.UTF8.GetString(data, 0, System.Math.Min(data.Length, 1024)).TrimStart('\uFEFF', ' ', '\t', '\r', '\n');
            return head.StartsWith("<svg") || ((head.StartsWith("<?xml") || head.StartsWith("<!")) && head.Contains("<svg"));
        }

        static UIImage FromSvg(byte[] data)
        {
            try
            {
                var svg = new Svg.Skia.SKSvg();
                using var stream = new MemoryStream(data);
                var picture = svg.Load(stream);
                if (picture == null || picture.CullRect.Width <= 0 || picture.CullRect.Height <= 0) return null;
                return new UIImage(svg, picture);
            }
            catch (System.Exception)
            {
                return null;
            }
        }

        /// <summary>
        /// The bitmap to draw this image at, for about this many device pixels: a raster image is
        /// itself; a vector one is drawn afresh at that size (and kept), so it stays sharp.
        /// </summary>
        public Bitmap BitmapFor(double pixelWidth, double pixelHeight)
        {
            if (_bitmap != null) return _bitmap;
            var w = System.Math.Clamp((int)System.Math.Ceiling(pixelWidth), 1, 4096);
            var h = System.Math.Clamp((int)System.Math.Ceiling(pixelHeight), 1, 4096);
            if (_rasters.TryGetValue((w, h), out var done)) return done;
            // A resize asks for a new size every frame: keep only the last two.
            if (_rasterOrder.Count >= 2)
            {
                _rasters.Remove(_rasterOrder[0]);
                _rasterOrder.RemoveAt(0);
            }
            var info = new SkiaSharp.SKImageInfo(w, h, SkiaSharp.SKColorType.Bgra8888, SkiaSharp.SKAlphaType.Premul);
            using var raster = new SkiaSharp.SKBitmap(info);
            using (var canvas = new SkiaSharp.SKCanvas(raster))
            {
                canvas.Clear(SkiaSharp.SKColors.Transparent);
                var cull = _picture.CullRect;
                canvas.Scale(w / cull.Width, h / cull.Height);
                canvas.Translate(-cull.Left, -cull.Top);
                canvas.DrawPicture(_picture);
            }
            var result = new WriteableBitmap(new PixelSize(w, h), new Vector(96, 96), PixelFormat.Bgra8888, AlphaFormat.Premul);
            using (var buffer = result.Lock())
            {
                var bytes = raster.Bytes;
                for (var row = 0; row < h; row++)
                    System.Runtime.InteropServices.Marshal.Copy(bytes, row * raster.RowBytes, buffer.Address + row * buffer.RowBytes, w * 4);
            }
            _rasters[(w, h)] = result;
            _rasterOrder.Add((w, h));
            return result;
        }
    }

    /// <summary>A HaxeUI image display: draws its image stretched to the size HaxeUI gives it.</summary>
    public class UIImageView : Control, IColorFiltered
    {
        UIImage _image;
        float[] _matrix;

        public void SetEffectiveColorMatrix(float[] matrix)
        {
            _matrix = matrix;
            InvalidateVisual();
        }

        public double W { get; private set; }
        public double H { get; private set; }

        public UIImageView()
        {
            IsHitTestVisible = false;
        }

        public void SetImage(UIImage image)
        {
            _image = image;
            InvalidateVisual();
        }

        /// <summary>image-rendering: pixelated: scaled without smoothing.</summary>
        public void SetPixelated(bool pixelated)
        {
            RenderOptions.SetBitmapInterpolationMode(this, pixelated ? BitmapInterpolationMode.None : BitmapInterpolationMode.Unspecified);
            InvalidateVisual();
        }

        /// <summary>Sets position and size; NaN leaves that value as it was.</summary>
        public void SetBounds(double left, double top, double width, double height)
        {
            if (!double.IsNaN(left)) Canvas.SetLeft(this, left);
            if (!double.IsNaN(top)) Canvas.SetTop(this, top);
            if (!double.IsNaN(width)) Width = W = System.Math.Max(0, width);
            if (!double.IsNaN(height)) Height = H = System.Math.Max(0, height);
        }

        /// <summary>Only the given rect (in this view's own coordinates) shows.</summary>
        public void SetClip(bool enabled, double left, double top, double width, double height)
        {
            Clip = enabled ? new RectangleGeometry(new Rect(left, top, System.Math.Max(0, width), System.Math.Max(0, height))) : null;
        }

        public override void Render(DrawingContext context)
        {
            if (_image == null || W <= 0 || H <= 0) return;
            var scale = UIImage.DeviceScale(this);
            var bitmap = ColorMatrix.Filter(_image.BitmapFor(W * scale, H * scale), _matrix);
            context.DrawImage(bitmap, new Rect(0, 0, bitmap.PixelSize.Width, bitmap.PixelSize.Height), new Rect(0, 0, W, H));
        }
    }
}
