using Avalonia.Input;
using Avalonia.Media;

namespace HaxeUICs
{
    /// <summary>
    /// The HaxeUI style values a UIPanel paints, filled in by haxe.ui.backend.cs.StyleMapper.
    /// Colours are ARGB; 0 (alpha 0) means "none".
    /// </summary>
    public class UIStyle
    {
        public uint BackgroundColor;
        public uint BackgroundColorEnd;
        /// <summary>0 none, 1 vertical, 2 horizontal.</summary>
        public int GradientStyle;
        public double BackgroundOpacity = 1;

        public double BorderLeft, BorderTop, BorderRight, BorderBottom;
        public uint BorderLeftColor, BorderTopColor, BorderRightColor, BorderBottomColor;
        public double BorderOpacity = 1;

        public double RadiusTL, RadiusTR, RadiusBR, RadiusBL;

        public double Opacity = 1;
        public string Cursor;

        public UIImage BackgroundImage;
        /// <summary>Source rect within the image (left, top, right, bottom); NaN: the whole image.</summary>
        public double ClipL = double.NaN, ClipT = double.NaN, ClipR = double.NaN, ClipB = double.NaN;
        /// <summary>The 9-slice centre rect within the (clipped) source (left, top, right, bottom); NaN: no slicing.</summary>
        public double SliceL = double.NaN, SliceT = double.NaN, SliceR = double.NaN, SliceB = double.NaN;
        /// <summary>0 stretch, 1 repeat, 2 natural size.</summary>
        public int Repeat;

        internal bool HasClip => !double.IsNaN(ClipL) && !double.IsNaN(ClipT) && !double.IsNaN(ClipR) && !double.IsNaN(ClipB);
        internal bool HasSlice => !double.IsNaN(SliceL) && !double.IsNaN(SliceT) && !double.IsNaN(SliceR) && !double.IsNaN(SliceB);

        internal IBrush BackgroundBrush()
        {
            if (BackgroundColor == 0) return null;
            if (GradientStyle == 0 || BackgroundColorEnd == 0)
                return new SolidColorBrush(Color.FromUInt32(BackgroundColor), BackgroundOpacity);
            var horizontal = GradientStyle == 2;
            return new LinearGradientBrush
            {
                StartPoint = new Avalonia.RelativePoint(0, 0, Avalonia.RelativeUnit.Relative),
                EndPoint = horizontal
                    ? new Avalonia.RelativePoint(1, 0, Avalonia.RelativeUnit.Relative)
                    : new Avalonia.RelativePoint(0, 1, Avalonia.RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.FromUInt32(BackgroundColor), 0),
                    new GradientStop(Color.FromUInt32(BackgroundColorEnd), 1),
                },
                Opacity = BackgroundOpacity,
            };
        }

        internal IBrush BorderBrush(uint color)
        {
            return color == 0 ? null : new SolidColorBrush(Color.FromUInt32(color), BorderOpacity);
        }

        internal bool HasRadius => RadiusTL > 0 || RadiusTR > 0 || RadiusBR > 0 || RadiusBL > 0;

        internal bool UniformBorder =>
            BorderLeft == BorderTop && BorderTop == BorderRight && BorderRight == BorderBottom &&
            BorderLeftColor == BorderTopColor && BorderTopColor == BorderRightColor && BorderRightColor == BorderBottomColor;

        internal static Cursor CursorFor(string name)
        {
            switch (name)
            {
                case "pointer": return new Cursor(StandardCursorType.Hand);
                case "text": return new Cursor(StandardCursorType.Ibeam);
                case "move": return new Cursor(StandardCursorType.SizeAll);
                case "col-resize": return new Cursor(StandardCursorType.SizeWestEast);
                case "row-resize": return new Cursor(StandardCursorType.SizeNorthSouth);
                case "default": return new Cursor(StandardCursorType.Arrow);
                default: return null;
            }
        }
    }
}
