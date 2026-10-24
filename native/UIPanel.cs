using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Rendering;

namespace HaxeUICs
{
    /// <summary>
    /// One HaxeUI component's native surface. HaxeUI computes every position and size itself, so
    /// this is a Canvas that places itself at the bounds it is given and keeps two groups of children:
    /// "content" (the component's own text, image or input, always underneath) and child panels,
    /// whose indices match HaxeUI's childComponents.
    /// </summary>
    public class UIPanel : Canvas, ICustomHitTest
    {
        float[] _ownMatrix, _parentMatrix, _effectiveMatrix;

        /// <summary>This component's own colour filter (null for none); it reaches everything inside.</summary>
        public void SetColorMatrix(float[] own)
        {
            _ownMatrix = own;
            UpdateColorMatrix();
        }

        void SetParentColorMatrix(float[] parent)
        {
            _parentMatrix = parent;
            UpdateColorMatrix();
        }

        void UpdateColorMatrix()
        {
            var effective = ColorMatrix.Compose(_parentMatrix, _ownMatrix);
            if (SameMatrix(effective, _effectiveMatrix)) return;
            _effectiveMatrix = effective;
            foreach (var child in Children) PassColorMatrix(child);
        }

        void PassColorMatrix(Control child)
        {
            if (child is UIPanel panel) panel.SetParentColorMatrix(_effectiveMatrix);
            else if (child is IColorFiltered filtered) filtered.SetEffectiveColorMatrix(_effectiveMatrix);
        }

        static bool SameMatrix(float[] a, float[] b) =>
            a == b || (a != null && b != null && System.Linq.Enumerable.SequenceEqual(a, b));

        int _contentCount;
        readonly UIPainter _painter;
        string _cursorName;
        double _blur;

        /// <summary>Takes the style to paint (the same instance may come back changed) and repaints.</summary>
        public void ApplyStyle(UIStyle style)
        {
            _painter.Style = style;
            Opacity = style.Opacity;
            if (style.Blur != _blur)
            {
                _blur = style.Blur;
                // CSS blur(n) is a Gaussian of standard deviation n; Avalonia's radius 4n matches html5's
                // blur(n) in the gallery (measured by how far the blurred text spreads).
                Effect = _blur > 0 ? new BlurEffect { Radius = _blur * 4 } : null;
            }
            if (style.Cursor != _cursorName)
            {
                _cursorName = style.Cursor;
                if (!_cursorSuppressed) Cursor = UIStyle.CursorFor(style.Cursor);
            }
            _painter.InvalidateVisual();
        }

        public UIPanel()
        {
            // Panel.Render is sealed in Avalonia 12, so a painter child underneath everything does the drawing.
            _painter = new UIPainter();
            AddContent(_painter);
        }

        bool _cursorSuppressed;

        /// <summary>The CSS cursor this panel shows; null when it has none or it is disabled.</summary>
        public string CursorName => _cursorSuppressed ? null : _cursorName;

        /// <summary>A disabled component drops its cursor (as html5 does) and gets it back when enabled.</summary>
        public void SetCursorSuppressed(bool suppressed)
        {
            if (suppressed == _cursorSuppressed) return;
            _cursorSuppressed = suppressed;
            Cursor = suppressed ? null : UIStyle.CursorFor(_cursorName);
        }

        public double Left { get; private set; }
        public double Top { get; private set; }
        public double W { get; private set; }
        public double H { get; private set; }

        public bool ClipEnabled { get; private set; }
        public double ClipLeft { get; private set; }
        public double ClipTop { get; private set; }
        public double ClipWidth { get; private set; }
        public double ClipHeight { get; private set; }

        public int ChildCount => Children.Count - _contentCount;

        EventRouter _events;

        /// <summary>The component's canvas drawing, painted over its style and under its children.</summary>
        public void SetGraphics(UIGraphics graphics)
        {
            if (_painter.Graphics != null) _painter.Graphics.Changed = null;
            _painter.Graphics = graphics;
            if (graphics != null) graphics.Changed = _painter.InvalidateVisual;
            _painter.InvalidateVisual();
        }

        /// <summary>Forwards the input kinds in the mask (EventKind flags) to the listener; 0 stops it.</summary>
        public void Listen(int kinds, IPanelListener listener)
        {
            if (_events == null)
            {
                if (kinds == 0) return;
                _events = new EventRouter(this, false);
            }
            _events.Update(kinds, listener);
        }

        /// <summary>Sets position and size; NaN leaves that value as it was.</summary>
        public void SetBounds(double left, double top, double width, double height)
        {
            if (!double.IsNaN(left)) Left = left;
            if (!double.IsNaN(top)) Top = top;
            if (!double.IsNaN(width)) W = System.Math.Max(0, width);
            if (!double.IsNaN(height)) H = System.Math.Max(0, height);
            Width = W;
            Height = H;
            _painter.Width = W;
            _painter.Height = H;
            if (!double.IsNaN(_insetTop)) UpdateClip(); // the inset is measured from the edges
            Place();
        }

        /// <summary>
        /// HaxeUI's clipRect, in this panel's own coordinates: only that rect shows, and the panel
        /// moves by -left/-top so the rect's corner sits at the component's position (scrolling).
        /// </summary>
        public void SetClip(bool enabled, double left, double top, double width, double height)
        {
            ClipEnabled = enabled;
            ClipLeft = enabled ? left : 0;
            ClipTop = enabled ? top : 0;
            ClipWidth = enabled ? width : 0;
            ClipHeight = enabled ? height : 0;
            UpdateClip();
            Place();
        }

        double _insetTop = double.NaN, _insetRight, _insetBottom, _insetLeft;

        /// <summary>CSS clip-path: inset(top right bottom left), within HaxeUI's own clip; NaN clears it.</summary>
        public void SetClipInset(double top, double right, double bottom, double left)
        {
            _insetTop = top;
            _insetRight = right;
            _insetBottom = bottom;
            _insetLeft = left;
            UpdateClip();
        }

        /// <summary>The rect that shows: HaxeUI's clip rect and the clip-path inset, either or both.</summary>
        Rect? VisibleRect()
        {
            Rect? visible = ClipEnabled ? new Rect(ClipLeft, ClipTop, System.Math.Max(0, ClipWidth), System.Math.Max(0, ClipHeight)) : (Rect?)null;
            if (!double.IsNaN(_insetTop))
            {
                var inset = new Rect(_insetLeft, _insetTop, System.Math.Max(0, W - _insetLeft - _insetRight), System.Math.Max(0, H - _insetTop - _insetBottom));
                visible = visible.HasValue ? visible.Value.Intersect(inset) : inset;
            }
            return visible;
        }

        void UpdateClip()
        {
            var visible = VisibleRect();
            Clip = visible.HasValue ? new RectangleGeometry(visible.Value) : null;
        }

        /// <summary>html5's rotation directive: turned about the panel's centre, in degrees.</summary>
        public void SetRotation(double degrees)
        {
            RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
            RenderTransform = degrees == 0 || double.IsNaN(degrees) ? null : new RotateTransform(degrees);
        }

        public void SetVisible(bool visible)
        {
            IsVisible = visible;
        }

        public void InsertChild(Control child, int index)
        {
            Detach(child);
            var at = _contentCount + System.Math.Clamp(index, 0, ChildCount);
            Children.Insert(at, child);
            PassColorMatrix(child);
        }

        /// <summary>
        /// HaxeUI adds a component elsewhere without removing it first (html5 and heaps move the
        /// node); Avalonia refuses a second parent, so the old one lets go first.
        /// </summary>
        static void Detach(Control child)
        {
            if (child.Parent is UIPanel panel) panel.RemoveChild(child);
            else if (child.Parent is Panel other) other.Children.Remove(child);
        }

        public void RemoveChild(Control child)
        {
            var at = Children.IndexOf(child);
            if (at < 0) return;
            Children.RemoveAt(at);
            if (at < _contentCount) _contentCount--;
        }

        public void MoveChild(Control child, int index)
        {
            var at = Children.IndexOf(child);
            if (at < _contentCount) return;
            Children.RemoveAt(at);
            InsertChild(child, index);
        }

        /// <summary>Index among child panels (the HaxeUI childComponents index), or -1.</summary>
        public int IndexOfChild(Control child)
        {
            var at = Children.IndexOf(child);
            return at < _contentCount ? -1 : at - _contentCount;
        }

        /// <summary>Adds the component's own text, image or input underneath its child panels.</summary>
        public void AddContent(Control content)
        {
            Detach(content);
            Children.Insert(_contentCount, content);
            _contentCount++;
            PassColorMatrix(content);
        }

        public bool HitTest(Point point)
        {
            var visible = VisibleRect();
            if (visible.HasValue && !visible.Value.Contains(point)) return false;
            return point.X >= 0 && point.Y >= 0 && point.X < W && point.Y < H;
        }

        void Place()
        {
            SetLeft(this, Left - ClipLeft);
            SetTop(this, Top - ClipTop);
        }
    }

    /// <summary>Paints a UIPanel's own style (background, then border) beneath its content and children.</summary>
    public class UIPainter : Control, IColorFiltered
    {
        public UIStyle Style;
        public UIGraphics Graphics;
        float[] _matrix;

        public void SetEffectiveColorMatrix(float[] matrix)
        {
            _matrix = matrix;
            InvalidateVisual();
        }

        public UIPainter()
        {
            IsHitTestVisible = false;
        }

        public override void Render(DrawingContext context)
        {
            if (Style != null) Style.PaintMatrix = _matrix;
            RenderStyle(context);
            Graphics?.Render(context, _matrix);
        }

        void RenderStyle(DrawingContext context)
        {
            var s = Style;
            var width = Bounds.Width;
            var height = Bounds.Height;
            if (s == null || width <= 0 || height <= 0) return;
            var bounds = new Rect(0, 0, width, height);

            var background = s.BackgroundBrush();
            if (s.Shadows.Count > 0)
            {
                // Shadows hug the background's rounded rect, drawn with it (outside, or inset inside).
                context.DrawRectangle(background, null, new RoundedRect(bounds, s.RadiusTL, s.RadiusTR, s.RadiusBR, s.RadiusBL), s.PaintShadows());
            }
            else if (background != null)
            {
                if (s.HasRadius)
                    context.DrawRectangle(background, null, new RoundedRect(bounds, s.RadiusTL, s.RadiusTR, s.RadiusBR, s.RadiusBL));
                else
                    context.FillRectangle(background, bounds);
            }

            if (s.BackgroundImage != null) RenderBackgroundImage(context, s, bounds);

            RenderBorder(context, s, bounds);
        }

        static void RenderBackgroundImage(DrawingContext context, UIStyle s, Rect bounds)
        {
            var image = ColorMatrix.Filter(s.BackgroundImage.Bitmap, s.PaintMatrix);
            var source = s.HasClip
                ? new Rect(s.ClipL, s.ClipT, s.ClipR - s.ClipL, s.ClipB - s.ClipT)
                : new Rect(0, 0, image.PixelSize.Width, image.PixelSize.Height);
            if (source.Width <= 0 || source.Height <= 0) return;

            // Within the background's rounded corners, as html5 clips it; pixelated if asked.
            System.IDisposable corners = s.HasRadius ? context.PushGeometryClip(RoundedPath(bounds, new Vector(s.RadiusTL, s.RadiusTL),
                new Vector(s.RadiusTR, s.RadiusTR), new Vector(s.RadiusBR, s.RadiusBR), new Vector(s.RadiusBL, s.RadiusBL))) : null;
            System.IDisposable smoothing = s.Pixelated ? context.PushRenderOptions(new RenderOptions { BitmapInterpolationMode = BitmapInterpolationMode.None }) : null;
            try
            {
                if (s.HasSlice)
                {
                    // Source columns/rows around the centre rect; destination keeps the corners' size.
                    // With repeat, the edges and centre are tiled at their own size (as heaps does)
                    // instead of stretched.
                    double[] sx = { source.X, source.X + s.SliceL, source.X + s.SliceR, source.Right };
                    double[] sy = { source.Y, source.Y + s.SliceT, source.Y + s.SliceB, source.Bottom };
                    double[] dx = { 0, s.SliceL, bounds.Width - (source.Width - s.SliceR), bounds.Width };
                    double[] dy = { 0, s.SliceT, bounds.Height - (source.Height - s.SliceB), bounds.Height };
                    for (var row = 0; row < 3; row++)
                        for (var col = 0; col < 3; col++)
                        {
                            var part = new Rect(sx[col], sy[row], sx[col + 1] - sx[col], sy[row + 1] - sy[row]);
                            var into = new Rect(dx[col], dy[row], dx[col + 1] - dx[col], dy[row + 1] - dy[row]);
                            if (s.Repeat == 1 && (row == 1 || col == 1)) DrawTiled(context, image, part, into, col == 1, row == 1);
                            else DrawPart(context, image, part, into);
                        }
                    return;
                }

                var size = DrawSize(s, source, bounds);
                switch (s.Repeat)
                {
                    case 1:
                        DrawTiled(context, image, source, bounds, true, true, size);
                        break;
                    case 2:
                        DrawPart(context, image, source, new Rect(0, 0, size.Width, size.Height));
                        break;
                    default:
                        DrawPart(context, image, source, bounds);
                        break;
                }
            }
            finally
            {
                smoothing?.Dispose();
                corners?.Dispose();
            }
        }

        /// <summary>background-width/-height (px or %), keeping the image's shape for a side not given.</summary>
        static Size DrawSize(UIStyle s, Rect source, Rect bounds)
        {
            var w = !double.IsNaN(s.BgWidth) ? s.BgWidth : !double.IsNaN(s.BgWidthPercent) ? bounds.Width * s.BgWidthPercent / 100 : double.NaN;
            var h = !double.IsNaN(s.BgHeight) ? s.BgHeight : !double.IsNaN(s.BgHeightPercent) ? bounds.Height * s.BgHeightPercent / 100 : double.NaN;
            if (double.IsNaN(w) && double.IsNaN(h)) return source.Size;
            if (double.IsNaN(w)) w = h * source.Width / source.Height;
            if (double.IsNaN(h)) h = w * source.Height / source.Width;
            return new Size(w, h);
        }

        /// <summary>Repeats a source rect across a destination, along x, y or both; stretched along the other.</summary>
        static void DrawTiled(DrawingContext context, Bitmap image, Rect source, Rect into, bool alongX, bool alongY, Size? tile = null)
        {
            if (into.Width <= 0 || into.Height <= 0) return;
            var step = tile ?? source.Size;
            var stepX = alongX ? step.Width : into.Width;
            var stepY = alongY ? step.Height : into.Height;
            if (stepX <= 0 || stepY <= 0) return;
            using (context.PushClip(into))
            {
                for (var y = into.Y; y < into.Bottom; y += stepY)
                    for (var x = into.X; x < into.Right; x += stepX)
                        DrawPart(context, image, source, new Rect(x, y, stepX, stepY));
            }
        }

        static void DrawPart(DrawingContext context, Bitmap image, Rect source, Rect destination)
        {
            if (source.Width > 0 && source.Height > 0 && destination.Width > 0 && destination.Height > 0)
                context.DrawImage(image, source, destination);
        }

        static void RenderBorder(DrawingContext context, UIStyle s, Rect bounds)
        {
            if (s.UniformBorder)
            {
                var size = s.BorderLeft;
                var brush = s.BorderBrush(s.BorderLeftColor);
                if (size <= 0 || brush == null) return;
                // A pen is centred on its path: inset by half its width so the border sits inside.
                var inner = bounds.Deflate(size / 2);
                var half = size / 2;
                context.DrawRectangle(null, s.BorderPen(brush, size), new RoundedRect(inner,
                    System.Math.Max(0, s.RadiusTL - half), System.Math.Max(0, s.RadiusTR - half),
                    System.Math.Max(0, s.RadiusBR - half), System.Math.Max(0, s.RadiusBL - half)));
                return;
            }
            if (s.BorderStyle != 0)
            {
                // Dashed or dotted sides are stroked along each side's centre line.
                StrokeSide(context, s, s.BorderTopColor, s.BorderTop, new Point(0, s.BorderTop / 2), new Point(bounds.Width, s.BorderTop / 2));
                StrokeSide(context, s, s.BorderRightColor, s.BorderRight, new Point(bounds.Width - s.BorderRight / 2, 0), new Point(bounds.Width - s.BorderRight / 2, bounds.Height));
                StrokeSide(context, s, s.BorderBottomColor, s.BorderBottom, new Point(bounds.Width, bounds.Height - s.BorderBottom / 2), new Point(0, bounds.Height - s.BorderBottom / 2));
                StrokeSide(context, s, s.BorderLeftColor, s.BorderLeft, new Point(s.BorderLeft / 2, bounds.Height), new Point(s.BorderLeft / 2, 0));
                return;
            }
            if (!s.HasRadius)
            {
                FillSide(context, s.BorderBrush(s.BorderLeftColor), new Rect(0, 0, s.BorderLeft, bounds.Height));
                FillSide(context, s.BorderBrush(s.BorderRightColor), new Rect(bounds.Width - s.BorderRight, 0, s.BorderRight, bounds.Height));
                FillSide(context, s.BorderBrush(s.BorderTopColor), new Rect(0, 0, bounds.Width, s.BorderTop));
                FillSide(context, s.BorderBrush(s.BorderBottomColor), new Rect(0, bounds.Height - s.BorderBottom, bounds.Width, s.BorderBottom));
                return;
            }
            // Rounded: the border is the ring between the outer rounded rect and the inner one (each
            // corner's radius less the two sides meeting there), and each side's colour fills its share
            // of the ring: the trapezoid from its two outer corners in to its two inner ones, as CSS does.
            double l = s.BorderLeft, t = s.BorderTop, r = s.BorderRight, b = s.BorderBottom;
            double w = bounds.Width, h = bounds.Height;
            var outer = RoundedPath(bounds, new Vector(s.RadiusTL, s.RadiusTL), new Vector(s.RadiusTR, s.RadiusTR),
                new Vector(s.RadiusBR, s.RadiusBR), new Vector(s.RadiusBL, s.RadiusBL));
            var hole = RoundedPath(new Rect(l, t, System.Math.Max(0, w - l - r), System.Math.Max(0, h - t - b)),
                new Vector(System.Math.Max(0, s.RadiusTL - l), System.Math.Max(0, s.RadiusTL - t)),
                new Vector(System.Math.Max(0, s.RadiusTR - r), System.Math.Max(0, s.RadiusTR - t)),
                new Vector(System.Math.Max(0, s.RadiusBR - r), System.Math.Max(0, s.RadiusBR - b)),
                new Vector(System.Math.Max(0, s.RadiusBL - l), System.Math.Max(0, s.RadiusBL - b)));
            var ring = new CombinedGeometry(GeometryCombineMode.Exclude, outer, hole);
            FillShare(context, s.BorderBrush(s.BorderTopColor), t, ring, new Point(0, 0), new Point(w, 0), new Point(w - r, t), new Point(l, t));
            FillShare(context, s.BorderBrush(s.BorderRightColor), r, ring, new Point(w, 0), new Point(w, h), new Point(w - r, h - b), new Point(w - r, t));
            FillShare(context, s.BorderBrush(s.BorderBottomColor), b, ring, new Point(w, h), new Point(0, h), new Point(l, h - b), new Point(w - r, h - b));
            FillShare(context, s.BorderBrush(s.BorderLeftColor), l, ring, new Point(0, h), new Point(0, 0), new Point(l, t), new Point(l, h - b));
        }

        static void StrokeSide(DrawingContext context, UIStyle s, uint color, double size, Point from, Point to)
        {
            var brush = s.BorderBrush(color);
            if (brush != null && size > 0) context.DrawLine(s.BorderPen(brush, size), from, to);
        }

        static void FillSide(DrawingContext context, IBrush brush, Rect side)
        {
            if (brush != null && side.Width > 0 && side.Height > 0) context.FillRectangle(brush, side);
        }

        /// <summary>Fills one side's share of a rounded border ring: the ring, clipped to its trapezoid.</summary>
        static void FillShare(DrawingContext context, IBrush brush, double size, Geometry ring, Point a, Point b, Point c, Point d)
        {
            if (brush == null || size <= 0) return;
            var share = new StreamGeometry();
            using (var g = share.Open())
            {
                g.BeginFigure(a, true);
                g.LineTo(b);
                g.LineTo(c);
                g.LineTo(d);
                g.EndFigure(true);
            }
            using (context.PushGeometryClip(share))
                context.DrawGeometry(brush, null, ring);
        }

        /// <summary>A rect with each corner rounded by its own (x, y) radii.</summary>
        static Geometry RoundedPath(Rect r, Vector tl, Vector tr, Vector br, Vector bl)
        {
            var path = new StreamGeometry();
            using (var g = path.Open())
            {
                g.BeginFigure(new Point(r.Left + tl.X, r.Top), true);
                g.LineTo(new Point(r.Right - tr.X, r.Top));
                if (tr.X > 0 && tr.Y > 0) g.ArcTo(new Point(r.Right, r.Top + tr.Y), new Size(tr.X, tr.Y), 0, false, SweepDirection.Clockwise);
                g.LineTo(new Point(r.Right, r.Bottom - br.Y));
                if (br.X > 0 && br.Y > 0) g.ArcTo(new Point(r.Right - br.X, r.Bottom), new Size(br.X, br.Y), 0, false, SweepDirection.Clockwise);
                g.LineTo(new Point(r.Left + bl.X, r.Bottom));
                if (bl.X > 0 && bl.Y > 0) g.ArcTo(new Point(r.Left, r.Bottom - bl.Y), new Size(bl.X, bl.Y), 0, false, SweepDirection.Clockwise);
                g.LineTo(new Point(r.Left, r.Top + tl.Y));
                if (tl.X > 0 && tl.Y > 0) g.ArcTo(new Point(r.Left + tl.X, r.Top), new Size(tl.X, tl.Y), 0, false, SweepDirection.Clockwise);
                g.EndFigure(true);
            }
            return path;
        }
    }
}
