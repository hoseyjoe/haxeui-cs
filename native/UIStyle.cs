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
        /// <summary>0 stretch, 1 repeat, 2 natural size. With a slice, repeat tiles the edges and centre.</summary>
        public int Repeat;
        /// <summary>background-width/-height in px, or in percent of the panel; NaN when not given.</summary>
        public double BgWidth = double.NaN, BgHeight = double.NaN, BgWidthPercent = double.NaN, BgHeightPercent = double.NaN;
        /// <summary>image-rendering: pixelated (no smoothing when scaled).</summary>
        public bool Pixelated;

        internal bool HasClip => !double.IsNaN(ClipL) && !double.IsNaN(ClipT) && !double.IsNaN(ClipR) && !double.IsNaN(ClipB);
        internal bool HasSlice => !double.IsNaN(SliceL) && !double.IsNaN(SliceT) && !double.IsNaN(SliceR) && !double.IsNaN(SliceB);

        /// <summary>The colour filter in force while this style is painted (set by UIPainter), or null.</summary>
        internal float[] PaintMatrix;

        // Brushes are kept between renders and made again only when what they show changes.
        IBrush _background;
        bool _backgroundMade;
        (uint, uint, int, double, float[]) _backgroundKey;
        readonly System.Collections.Generic.Dictionary<(uint, double, float[]), IBrush> _borders =
            new System.Collections.Generic.Dictionary<(uint, double, float[]), IBrush>();

        internal IBrush BackgroundBrush()
        {
            var key = (BackgroundColor, BackgroundColorEnd, GradientStyle, BackgroundOpacity, PaintMatrix);
            if (!_backgroundMade || !key.Equals(_backgroundKey))
            {
                _background = ColorMatrix.Brush(UnfilteredBackgroundBrush(), PaintMatrix);
                _backgroundKey = key;
                _backgroundMade = true;
            }
            return _background;
        }

        /// <summary>The shadows, their colours through the paint-time colour filter.</summary>
        internal BoxShadows PaintShadows()
        {
            if (PaintMatrix == null || _shadows.Count == 0) return Shadows;
            var mapped = _shadows.ConvertAll(sh => { sh.Color = ColorMatrix.Apply(PaintMatrix, sh.Color); return sh; });
            return mapped.Count == 1 ? new BoxShadows(mapped[0]) : new BoxShadows(mapped[0], mapped.GetRange(1, mapped.Count - 1).ToArray());
        }

        IBrush UnfilteredBackgroundBrush()
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
            if (color == 0) return null;
            var key = (color, BorderOpacity, PaintMatrix);
            if (!_borders.TryGetValue(key, out var brush))
            {
                if (_borders.Count >= 8) _borders.Clear(); // a style shows at most four border colours
                brush = ColorMatrix.Brush(new SolidColorBrush(Color.FromUInt32(color), BorderOpacity), PaintMatrix);
                _borders[key] = brush;
            }
            return brush;
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

        /// <summary>CSS cursor names, as the Avalonia cursor that stands in for each.</summary>
        static readonly System.Collections.Generic.Dictionary<string, StandardCursorType> CursorTypes =
            new System.Collections.Generic.Dictionary<string, StandardCursorType>
            {
                ["default"] = StandardCursorType.Arrow,
                ["auto"] = StandardCursorType.Arrow,
                ["pointer"] = StandardCursorType.Hand,
                ["text"] = StandardCursorType.Ibeam,
                ["vertical-text"] = StandardCursorType.Ibeam,
                ["move"] = StandardCursorType.SizeAll,
                ["all-scroll"] = StandardCursorType.SizeAll,
                ["none"] = StandardCursorType.None,
                ["not-allowed"] = StandardCursorType.No,
                ["no-drop"] = StandardCursorType.No,
                ["wait"] = StandardCursorType.Wait,
                ["progress"] = StandardCursorType.AppStarting,
                ["crosshair"] = StandardCursorType.Cross,
                ["help"] = StandardCursorType.Help,
                ["grab"] = StandardCursorType.Hand,
                ["grabbing"] = StandardCursorType.DragMove,
                ["copy"] = StandardCursorType.DragCopy,
                ["alias"] = StandardCursorType.DragLink,
                ["col-resize"] = StandardCursorType.SizeWestEast,
                ["ew-resize"] = StandardCursorType.SizeWestEast,
                ["row-resize"] = StandardCursorType.SizeNorthSouth,
                ["ns-resize"] = StandardCursorType.SizeNorthSouth,
                ["nwse-resize"] = StandardCursorType.TopLeftCorner,
                ["nesw-resize"] = StandardCursorType.TopRightCorner,
                ["n-resize"] = StandardCursorType.TopSide,
                ["s-resize"] = StandardCursorType.BottomSide,
                ["e-resize"] = StandardCursorType.RightSide,
                ["w-resize"] = StandardCursorType.LeftSide,
                ["nw-resize"] = StandardCursorType.TopLeftCorner,
                ["se-resize"] = StandardCursorType.BottomRightCorner,
                ["ne-resize"] = StandardCursorType.TopRightCorner,
                ["sw-resize"] = StandardCursorType.BottomLeftCorner,
            };

        /// <summary>The Avalonia StandardCursorType name for a CSS cursor, or null when it has none.</summary>
        public static string StandardCursorName(string css)
        {
            return css != null && CursorTypes.TryGetValue(css, out var type) ? type.ToString() : null;
        }

        internal static Cursor CursorFor(string name)
        {
            return name != null && CursorTypes.TryGetValue(name, out var type) ? new Cursor(type) : null;
        }
    }
}
