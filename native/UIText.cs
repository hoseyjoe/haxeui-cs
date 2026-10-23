using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace HaxeUICs
{
    /// <summary>
    /// A HaxeUI text display: a TextBlock HaxeUI positions and sizes itself, which can also report
    /// the size its text needs (unbounded, or wrapped at a width).
    /// </summary>
    public class UIText : TextBlock
    {
        public double MeasuredWidth { get; private set; }
        public double MeasuredHeight { get; private set; }

        public bool IsBold => FontWeight >= FontWeight.Bold;

        public UIText()
        {
            IsHitTestVisible = false;
            TextWrapping = TextWrapping.NoWrap;
        }

        public void SetFont(string family, double size, bool bold, bool italic, bool underline)
        {
            FontFamily = UIFonts.ResolveFamily(family);
            FontSize = size > 0 ? size : 13;
            FontWeight = bold ? FontWeight.Bold : FontWeight.Normal;
            FontStyle = italic ? FontStyle.Italic : FontStyle.Normal;
            TextDecorations = underline ? Avalonia.Media.TextDecorations.Underline : null;
        }

        public void SetColor(uint argb)
        {
            Foreground = new SolidColorBrush(Color.FromUInt32(argb));
        }

        /// <summary>0 left, 1 center, 2 right.</summary>
        public void SetAlign(int align)
        {
            TextAlignment = align == 1 ? TextAlignment.Center : align == 2 ? TextAlignment.Right : TextAlignment.Left;
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
