using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace HaxeUICs
{
    /// <summary>
    /// A HaxeUI text display: a TextBlock HaxeUI positions and sizes itself, which can also report
    /// the size its text needs (unbounded, or wrapped at a width).
    /// </summary>
    public class UIText : TextBlock, IColorFiltered
    {
        float[] _matrix;
        uint _color = 0xFF000000;
        double _shadowX, _shadowY, _shadowBlur;
        uint _shadowColor;

        public void SetEffectiveColorMatrix(float[] matrix)
        {
            _matrix = matrix;
            SetColor(_color);
            SetShadow(_shadowX, _shadowY, _shadowBlur, _shadowColor);
        }

        public double MeasuredWidth { get; private set; }
        public double MeasuredHeight { get; private set; }

        public bool IsBold => FontWeight >= FontWeight.Bold;

        public UIText()
        {
            IsHitTestVisible = false;
            TextWrapping = TextWrapping.NoWrap;
        }

        public void SetFont(string family, double size, bool bold, bool italic, bool underline, bool strikethrough)
        {
            FontFamily = UIFonts.ResolveFamily(family);
            FontSize = size > 0 ? size : 13;
            FontWeight = bold ? FontWeight.Bold : FontWeight.Normal;
            FontStyle = italic ? FontStyle.Italic : FontStyle.Normal;
            TextDecorations = UIFonts.Decorations(underline, strikethrough);
        }

        public void SetColor(uint argb)
        {
            _color = argb;
            Foreground = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)));
        }

        /// <summary>0 left, 1 center, 2 right, 3 justify.</summary>
        public void SetAlign(int align)
        {
            TextAlignment = align == 1 ? TextAlignment.Center : align == 2 ? TextAlignment.Right
                : align == 3 ? TextAlignment.Justify : TextAlignment.Left;
        }

        /// <summary>A shadow of the glyphs (haxeui-cs's text-shadow); argb 0 removes it.</summary>
        public void SetShadow(double dx, double dy, double blur, uint argb)
        {
            _shadowX = dx;
            _shadowY = dy;
            _shadowBlur = blur;
            _shadowColor = argb;
            argb = argb == 0 ? 0 : ColorMatrix.Apply(_matrix, argb);
            Effect = argb == 0 ? null : new DropShadowEffect
            {
                OffsetX = dx,
                OffsetY = dy,
                BlurRadius = System.Math.Max(0, blur),
                Color = Color.FromUInt32(argb | 0xFF000000u),
                Opacity = ((argb >> 24) & 0xFF) / 255.0,
            };
        }

        public void SetWrap(bool wrap)
        {
            TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap;
        }

        /// <summary>Sets position and size; NaN leaves that value as it was.</summary>
        public void SetBounds(double left, double top, double width, double height)
        {
            if (!double.IsNaN(left)) Canvas.SetLeft(this, left);
            if (!double.IsNaN(top)) Canvas.SetTop(this, top);
            if (!double.IsNaN(width)) Width = System.Math.Max(0, width);
            if (!double.IsNaN(height)) Height = System.Math.Max(0, height);
        }

        /// <summary>
        /// Measures the text as it would lay out within maxWidth (0 or less: no limit), ignoring the
        /// size HaxeUI last gave it. Empty text measures as one line, so an empty label keeps its height.
        /// </summary>
        public void MeasureText(double maxWidth)
        {
            var width = Width;
            var height = Height;
            var text = Text;
            if (string.IsNullOrEmpty(text)) Text = "|";
            Width = double.NaN;
            Height = double.NaN;
            Measure(new Size(maxWidth > 0 ? maxWidth : double.PositiveInfinity, double.PositiveInfinity));
            MeasuredWidth = string.IsNullOrEmpty(text) ? 0 : System.Math.Ceiling(DesiredSize.Width);
            MeasuredHeight = System.Math.Ceiling(DesiredSize.Height);
            Text = text;
            Width = width;
            Height = height;
        }
    }
}
