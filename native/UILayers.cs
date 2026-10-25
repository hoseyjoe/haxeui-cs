using System.Collections.Generic;
using Avalonia;
using Avalonia.Media;
using Avalonia.Platform;
using Avalonia.Rendering.SceneGraph;
using Avalonia.Skia;
using SkiaSharp;

namespace HaxeUICs
{
    /// <summary>
    /// Retained layers drawn over a canvas's own drawing: a tree of groups, each with a matrix, an
    /// opacity and an optional mask, holding bitmaps placed in their group's units. For content that
    /// moves every frame while its pixels mostly don't, such as an animated SVG's layers: placing a
    /// group again costs a repaint, not a raster. A group that fades is composited as one image.
    ///
    /// Drawn straight through Skia (offscreen layers, as heaps' filters are): Avalonia's own opacity
    /// mask maps an image brush wrongly once the window has a render scaling (150%), and its
    /// PushOpacity fades each drawing on its own, so a group's overlaps would show.
    /// </summary>
    public class UILayers
    {
        class Layer
        {
            public bool IsGroup;
            public Matrix Matrix = Matrix.Identity;
            public double Opacity = 1;
            public bool Visible = true;
            public SKImage Image;   // a bitmap's pixels; a group's mask. Never changed once made: the render thread may be drawing it
            public Rect Dest;       // where the pixels go, in the group's units
            public readonly List<int> Children = new List<int>();
        }

        readonly List<Layer> _layers = new List<Layer>();
        readonly List<int> _roots = new List<int>();

        /// <summary>Called when the layers change, so their owner repaints.</summary>
        internal System.Action Changed;

        public int Count => _layers.Count;

        /// <summary>A new group inside `parent` (-1: at the top), drawn above what is already there.</summary>
        public int AddGroup(int parent) => Add(parent, true);

        /// <summary>A new bitmap inside `parent` (-1: at the top), empty until SetPixels.</summary>
        public int AddBitmap(int parent) => Add(parent, false);

        int Add(int parent, bool group)
        {
            var siblings = parent >= 0 && parent < _layers.Count && _layers[parent].IsGroup ? _layers[parent].Children : _roots;
            _layers.Add(new Layer { IsGroup = group });
            siblings.Add(_layers.Count - 1);
            return _layers.Count - 1;
        }

        /// <summary>
        /// Places a layer in its group: x' = a·x + c·y + e, y' = b·x + d·y + f, as an SVG matrix(a b c d e f).
        /// </summary>
        public void SetMatrix(int layer, double a, double b, double c, double d, double e, double f)
        {
            if (!Has(layer)) return;
            var m = new Matrix(a, b, c, d, e, f);
            if (_layers[layer].Matrix == m) return;
            _layers[layer].Matrix = m;
            Changed?.Invoke();
        }

        public void SetOpacity(int layer, double opacity)
        {
            if (!Has(layer)) return;
            opacity = System.Math.Clamp(opacity, 0, 1);
            if (_layers[layer].Opacity == opacity) return;
            _layers[layer].Opacity = opacity;
            Changed?.Invoke();
        }

        public void SetVisible(int layer, bool visible)
        {
            if (!Has(layer) || _layers[layer].Visible == visible) return;
            _layers[layer].Visible = visible;
            Changed?.Invoke();
        }

        /// <summary>
        /// A bitmap's pixels, or a group's mask (its alpha; nothing of the group shows outside it):
        /// RGBA bytes, straight alpha, width × height, drawn into x, y, w × h of the group's units.
        /// Null or empty pixels draw nothing (and remove a group's mask).
        /// </summary>
        public void SetPixels(int layer, byte[] rgba, int width, int height, double x, double y, double w, double h)
        {
            if (!Has(layer)) return;
            var l = _layers[layer];
            l.Image = null;
            if (rgba != null && width > 0 && height > 0 && rgba.Length >= width * height * 4)
            {
                var info = new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Unpremul);
                l.Image = SKImage.FromPixelCopy(info, new System.ReadOnlySpan<byte>(rgba, 0, width * height * 4));
                l.Dest = new Rect(x, y, w, h);
            }
            Changed?.Invoke();
        }

        public void Clear()
        {
            _layers.Clear();
            _roots.Clear();
            Changed?.Invoke();
        }

        bool Has(int layer) => layer >= 0 && layer < _layers.Count;

        /// <param name="matrix">The colour filter in force (null for none): bitmaps go through it; masks don't.</param>
        public void Render(DrawingContext context, float[] matrix = null)
        {
            Rect? bounds = null;
            var roots = new List<Node>();
            foreach (var i in _roots)
            {
                var node = Snapshot(i, out var b);
                if (node == null) continue;
                roots.Add(node);
                bounds = bounds.HasValue ? bounds.Value.Union(b) : b;
            }
            if (bounds.HasValue) context.Custom(new Draw(roots, bounds.Value, matrix));
        }

        /// <summary>
        /// What the render thread draws for layer `i`, fixed now, and what it covers in its parent's
        /// units (after its matrix); null for nothing to draw.
        /// </summary>
        Node Snapshot(int i, out Rect bounds)
        {
            bounds = default;
            var l = _layers[i];
            if (!l.Visible || l.Opacity <= 0) return null;
            var node = new Node { Matrix = l.Matrix, Opacity = (float)l.Opacity };
            Rect own;
            if (!l.IsGroup)
            {
                if (l.Image == null) return null;
                node.Image = l.Image;
                node.Dest = l.Dest;
                own = l.Dest;
            }
            else
            {
                Rect? all = null;
                var children = new List<Node>();
                foreach (var c in l.Children)
                {
                    var child = Snapshot(c, out var b);
                    if (child == null) continue;
                    children.Add(child);
                    all = all.HasValue ? all.Value.Union(b) : b;
                }
                if (!all.HasValue) return null;
                node.Children = children;
                own = all.Value;
                if (l.Image != null)
                {
                    node.Mask = l.Image;
                    node.Dest = l.Dest;
                    own = own.Intersect(l.Dest);
                }
                node.Bounds = own;
            }
            bounds = own.TransformToAABB(l.Matrix);
            return node;
        }

        class Node
        {
            public Matrix Matrix;
            public float Opacity;
            public SKImage Image; // a bitmap
            public SKImage Mask;  // a group's
            public Rect Dest;
            public Rect Bounds;   // a group's, in its own units
            public List<Node> Children;
        }

        /// <summary>One paint of the layers, run on the render thread over a snapshot of them.</summary>
        class Draw : ICustomDrawOperation
        {
            static readonly SKSamplingOptions Smooth = new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.None);

            readonly List<Node> _roots;
            readonly float[] _colorMatrix;

            public Draw(List<Node> roots, Rect bounds, float[] colorMatrix)
            {
                _roots = roots;
                Bounds = bounds;
                _colorMatrix = colorMatrix;
            }

            public Rect Bounds { get; }

            public bool HitTest(Point p) => false;

            public bool Equals(ICustomDrawOperation other) => false; // every paint is a new one

            public void Dispose()
            {
            }

            public void Render(ImmediateDrawingContext context)
            {
                var feature = context.TryGetFeature<ISkiaSharpApiLeaseFeature>();
                if (feature == null) return;
                using var lease = feature.Lease();
                var canvas = lease.SkCanvas;
                using var paint = new SKPaint();
                if (_colorMatrix != null) paint.ColorFilter = SKColorFilter.CreateColorMatrix(_colorMatrix);
                foreach (var node in _roots) Paint(canvas, node, paint);
            }

            void Paint(SKCanvas canvas, Node node, SKPaint paint)
            {
                var saved = canvas.Save();
                var m = node.Matrix;
                var sk = new SKMatrix((float)m.M11, (float)m.M21, (float)m.M31, (float)m.M12, (float)m.M22, (float)m.M32, 0, 0, 1);
                canvas.Concat(in sk);
                if (node.Children == null)
                {
                    if (node.Opacity < 1)
                    {
                        using var faded = paint.Clone();
                        faded.Color = new SKColor(255, 255, 255, (byte)System.Math.Round(node.Opacity * 255));
                        canvas.DrawImage(node.Image, Sk(node.Dest), Smooth, faded);
                    }
                    else
                    {
                        canvas.DrawImage(node.Image, Sk(node.Dest), Smooth, paint);
                    }
                }
                else
                {
                    var bounds = Sk(node.Bounds);
                    if (node.Opacity < 1)
                    {
                        using var fade = new SKPaint { Color = new SKColor(255, 255, 255, (byte)System.Math.Round(node.Opacity * 255)) };
                        canvas.SaveLayer(bounds, fade); // the group drawn as one image, then faded
                    }
                    if (node.Mask != null)
                    {
                        canvas.ClipRect(Sk(node.Dest));
                        canvas.SaveLayer(bounds, null);
                    }
                    foreach (var child in node.Children) Paint(canvas, child, paint);
                    if (node.Mask != null)
                    {
                        using var keep = new SKPaint { BlendMode = SKBlendMode.DstIn };
                        canvas.DrawImage(node.Mask, Sk(node.Dest), Smooth, keep);
                    }
                }
                canvas.RestoreToCount(saved);
            }

            static SKRect Sk(Rect r) => new SKRect((float)r.Left, (float)r.Top, (float)r.Right, (float)r.Bottom);
        }
    }
}
