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
        /// <summary>0 solid, 1 dashed, 2 dotted.</summary>
        public int BorderStyle;

        public double RadiusTL, RadiusTR, RadiusBR, RadiusBL;

        public double Opacity = 1;
        public string Cursor;

        /// <summary>CSS filter: blur(n), in px; 0 for none. It blurs the panel and everything in it.</summary>
        public double Blur;

        /// <summary>Box shadows around (or, inset, inside) the background's rounded rect.</summary>
        public BoxShadows Shadows;
        readonly System.Collections.Generic.List<BoxShadow> _shadows = new System.Collections.Generic.List<BoxShadow>();

        public void ClearShadows()
        {
            _shadows.Clear();
            Shadows = default;
        }

        /// <param name="argb">The colour, its alpha the shadow's opacity.</param>
        public void AddShadow(double offsetX, double offsetY, double blur, double spread, uint argb, bool inset)
        {
            _shadows.Add(new BoxShadow
            {
                OffsetX = offsetX,
                OffsetY = offsetY,
                Blur = System.Math.Max(0, blur),
                Spread = System.Math.Max(0, spread),
                Color = Color.FromUInt32(argb),
                IsInset = inset,
            });
            Shadows = _shadows.Count == 1 ? new BoxShadows(_shadows[0]) : new BoxShadows(_shadows[0], _shadows.GetRange(1, _shadows.Count - 1).ToArray());
        }

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

        /// <summary>The pen for a border line of this width, dashed or dotted as BorderStyle says.</summary>
        internal Pen BorderPen(IBrush brush, double width)
        {
            switch (BorderStyle)
            {
                // Dash lengths are in multiples of the pen's width: dashes of 3 with gaps of 3, as
                // browsers draw them; dots are round caps on zero-length dashes, a dot apart.
                case 1: return new Pen(brush, width, new DashStyle(new double[] { 3, 3 }, 0), PenLineCap.Flat);
                case 2: return new Pen(brush, width, new DashStyle(new double[] { 0, 2 }, 0), PenLineCap.Round);
                default: return new Pen(brush, width);
            }
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
