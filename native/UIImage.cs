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
        public Bitmap Bitmap { get; }
        public int Width => Bitmap.PixelSize.Width;
        public int Height => Bitmap.PixelSize.Height;

        UIImage(Bitmap bitmap)
        {
            Bitmap = bitmap;
        }

        /// <summary>Decodes PNG/JPEG/etc. bytes; null when they are not an image.</summary>
        public static UIImage FromBytes(byte[] data)
        {
            if (data == null || data.Length == 0) return null;
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
    }

    /// <summary>A HaxeUI image display: draws its image stretched to the size HaxeUI gives it.</summary>
    public class UIImageView : Control
    {
        UIImage _image;

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
            context.DrawImage(_image.Bitmap, new Rect(0, 0, _image.Width, _image.Height), new Rect(0, 0, W, H));
        }
    }
}
