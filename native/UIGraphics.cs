using System.Collections.Generic;
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace HaxeUICs
{
    /// <summary>
    /// HaxeUI's canvas drawing for one component, recorded as commands and replayed when painted.
    /// Fills follow haxeui-heaps (Flash): FillStyle(true, c) begins a fill; every figure drawn until
    /// the fill ends (FillStyle(false), the next FillStyle, or the end) is filled, closed, even
    /// without BeginPath. Strokes draw as they go, over all fills.
    /// </summary>
    public class UIGraphics
    {
        enum Op { MoveTo, LineTo, CurveTo, CubicTo, Circle, Rectangle, Stroke, Fill, BeginPath, ClosePath, Image }

        struct Command
        {
            public Op Op;
            public double A, B, C, D, E, F;
            public bool Has;
            public uint Color;
            public UIImage Image;
        }

        readonly List<Command> _commands = new List<Command>();
        WriteableBitmap _pixels;

        /// <summary>Called when the drawing changes, so its owner repaints.</summary>
        internal System.Action Changed;

        public void Clear()
        {
            _commands.Clear();
            _pixels = null;
            Changed?.Invoke();
        }

        public void MoveTo(double x, double y) => Add(new Command { Op = Op.MoveTo, A = x, B = y });
        public void LineTo(double x, double y) => Add(new Command { Op = Op.LineTo, A = x, B = y });
        public void CurveTo(double cx, double cy, double ax, double ay) => Add(new Command { Op = Op.CurveTo, A = cx, B = cy, C = ax, D = ay });
        public void CubicCurveTo(double c1x, double c1y, double c2x, double c2y, double ax, double ay) =>
            Add(new Command { Op = Op.CubicTo, A = c1x, B = c1y, C = c2x, D = c2y, E = ax, F = ay });
        public void Circle(double x, double y, double radius) => Add(new Command { Op = Op.Circle, A = x, B = y, C = radius });
        public void Rectangle(double x, double y, double width, double height) => Add(new Command { Op = Op.Rectangle, A = x, B = y, C = width, D = height });
        public void StrokeStyle(bool has, uint argb, double thickness) => Add(new Command { Op = Op.Stroke, Has = has, Color = argb, A = thickness });
        public void FillStyle(bool has, uint argb) => Add(new Command { Op = Op.Fill, Has = has, Color = argb });
        public void BeginPath() => Add(new Command { Op = Op.BeginPath });
        public void ClosePath() => Add(new Command { Op = Op.ClosePath });
        public void Image(UIImage image, double x, double y, double width, double height) =>
            Add(new Command { Op = Op.Image, Image = image, A = x, B = y, C = width, D = height });

        /// <summary>Replaces the canvas's pixel layer: RGBA bytes, width × height.</summary>
        public void SetPixels(byte[] rgba, int width, int height)
        {
            if (rgba == null || width <= 0 || height <= 0 || rgba.Length < width * height * 4) return;
            _pixels = new WriteableBitmap(new PixelSize(width, height), new Vector(96, 96), PixelFormat.Rgba8888, AlphaFormat.Unpremul);
            using (var buffer = _pixels.Lock())
            {
                for (var row = 0; row < height; row++)
                    System.Runtime.InteropServices.Marshal.Copy(rgba, row * width * 4, buffer.Address + row * buffer.RowBytes, width * 4);
            }
            Changed?.Invoke();
        }

        /// <summary>
        /// Sets one pixel of the canvas's pixel layer (made at width x height when there is none,
        /// or when the canvas has changed size since).
        /// </summary>
        public void SetPixel(int x, int y, uint argb, int width, int height)
        {
            if (width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height) return;
            if (_pixels == null || _pixels.PixelSize.Width != width || _pixels.PixelSize.Height != height)
                _pixels = new WriteableBitmap(new PixelSize(width, height), new Vector(96, 96), PixelFormat.Rgba8888, AlphaFormat.Unpremul);
            using (var buffer = _pixels.Lock())
            {
                // RGBA bytes, as SetPixels writes them
                var at = buffer.Address + y * buffer.RowBytes + x * 4;
                System.Runtime.InteropServices.Marshal.WriteByte(at, (byte)(argb >> 16));
                System.Runtime.InteropServices.Marshal.WriteByte(at + 1, (byte)(argb >> 8));
                System.Runtime.InteropServices.Marshal.WriteByte(at + 2, (byte)argb);
                System.Runtime.InteropServices.Marshal.WriteByte(at + 3, (byte)(argb >> 24));
            }
            Changed?.Invoke();
        }

        void Add(Command command)
        {
            _commands.Add(command);
            Changed?.Invoke();
        }

        /// <param name="matrix">The colour filter in force (null for none): colours and images go through it.</param>
        public void Render(DrawingContext context, float[] matrix = null)
        {
            if (_pixels != null) context.DrawImage(ColorMatrix.Filter(_pixels, matrix), new Rect(0, 0, _pixels.Size.Width, _pixels.Size.Height));
            if (_commands.Count == 0) return;
            new Replay(context, matrix).Run(_commands);
        }

        /// <summary>One pass over the commands: fills (and images) draw in order, then every stroke on top.</summary>
        class Replay
        {
            readonly DrawingContext _context;
            readonly float[] _matrix;
            readonly List<(IPen pen, Geometry geometry)> _strokes = new List<(IPen, Geometry)>();

            IBrush _fill;
            PathGeometry _fillGeometry;
            PathFigure _fillFigure;

            IPen _pen;
            PathGeometry _strokeGeometry;
            PathFigure _strokeFigure;

            Point _position;

            public Replay(DrawingContext context, float[] matrix)
            {
                _context = context;
                _matrix = matrix;
            }

            public void Run(List<Command> commands)
            {
                foreach (var c in commands)
                {
                    switch (c.Op)
                    {
                        case Op.MoveTo:
                            _position = new Point(c.A, c.B);
                            _fillFigure = null;
                            _strokeFigure = null;
                            break;
                        case Op.LineTo:
                            Segment(new LineSegment { Point = new Point(c.A, c.B) });
                            _position = new Point(c.A, c.B);
                            break;
                        case Op.CurveTo:
                            Segment(new QuadraticBezierSegment { Point1 = new Point(c.A, c.B), Point2 = new Point(c.C, c.D) });
                            _position = new Point(c.C, c.D);
                            break;
                        case Op.CubicTo:
                            Segment(new BezierSegment { Point1 = new Point(c.A, c.B), Point2 = new Point(c.C, c.D), Point3 = new Point(c.E, c.F) });
                            _position = new Point(c.E, c.F);
                            break;
                        case Op.Circle:
                            Shape(new EllipseGeometry(new Rect(c.A - c.C, c.B - c.C, c.C * 2, c.C * 2)));
                            break;
                        case Op.Rectangle:
                            Shape(new RectangleGeometry(new Rect(c.A, c.B, c.C, c.D)));
                            break;
                        case Op.Stroke:
                            EndStroke();
                            _pen = c.Has ? new Pen(new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, c.Color))), c.A > 0 ? c.A : 1) : null;
                            break;
                        case Op.Fill:
                            EndFill();
                            _fill = c.Has ? new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, c.Color))) : null;
                            break;
                        case Op.BeginPath:
                            _fillFigure = null;
                            _strokeFigure = null;
                            break;
                        case Op.ClosePath:
                            if (_fillFigure != null) _fillFigure.IsClosed = true;
                            if (_strokeFigure != null) _strokeFigure.IsClosed = true;
                            break;
                        case Op.Image:
                            if (c.Image != null && c.C > 0 && c.D > 0)
                                _context.DrawImage(ColorMatrix.Filter(c.Image.Bitmap, _matrix), new Rect(0, 0, c.Image.Width, c.Image.Height), new Rect(c.A, c.B, c.C, c.D));
                            break;
                    }
                }
                EndFill();
                EndStroke();
                foreach (var (pen, geometry) in _strokes) _context.DrawGeometry(null, pen, geometry);
            }

            void Segment(PathSegment segment)
            {
                if (_fill != null)
                {
                    if (_fillFigure == null)
                    {
                        _fillGeometry ??= new PathGeometry();
                        _fillFigure = new PathFigure { StartPoint = _position, IsClosed = true, IsFilled = true, Segments = new PathSegments() };
                        _fillGeometry.Figures.Add(_fillFigure);
                    }
                    _fillFigure.Segments.Add(Clone(segment));
                }
                if (_pen != null)
                {
                    if (_strokeFigure == null)
                    {
                        _strokeGeometry ??= new PathGeometry();
                        _strokeFigure = new PathFigure { StartPoint = _position, IsClosed = false, IsFilled = false, Segments = new PathSegments() };
                        _strokeGeometry.Figures.Add(_strokeFigure);
                    }
                    _strokeFigure.Segments.Add(segment);
                }
            }

            void Shape(Geometry shape)
            {
                if (_fill != null) _context.DrawGeometry(_fill, null, shape);
                if (_pen != null) _strokes.Add((_pen, shape));
            }

            void EndFill()
            {
                if (_fill != null && _fillGeometry != null) _context.DrawGeometry(_fill, null, _fillGeometry);
                _fillGeometry = null;
                _fillFigure = null;
            }

            void EndStroke()
            {
                if (_pen != null && _strokeGeometry != null) _strokes.Add((_pen, _strokeGeometry));
                _strokeGeometry = null;
                _strokeFigure = null;
            }

            static PathSegment Clone(PathSegment segment)
            {
                switch (segment)
                {
                    case LineSegment l: return new LineSegment { Point = l.Point };
                    case QuadraticBezierSegment q: return new QuadraticBezierSegment { Point1 = q.Point1, Point2 = q.Point2 };
                    case BezierSegment b: return new BezierSegment { Point1 = b.Point1, Point2 = b.Point2, Point3 = b.Point3 };
                    default: return segment;
                }
            }
        }
    }
}
