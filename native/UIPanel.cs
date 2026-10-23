using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
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
        int _contentCount;

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

        /// <summary>Sets position and size; NaN leaves that value as it was.</summary>
        public void SetBounds(double left, double top, double width, double height)
        {
            if (!double.IsNaN(left)) Left = left;
            if (!double.IsNaN(top)) Top = top;
            if (!double.IsNaN(width)) W = System.Math.Max(0, width);
            if (!double.IsNaN(height)) H = System.Math.Max(0, height);
            Width = W;
            Height = H;
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
            Clip = enabled ? new RectangleGeometry(new Rect(left, top, System.Math.Max(0, width), System.Math.Max(0, height))) : null;
            Place();
        }

        public void SetVisible(bool visible)
        {
            IsVisible = visible;
        }

        public void InsertChild(Control child, int index)
        {
            var at = _contentCount + System.Math.Clamp(index, 0, ChildCount);
            Children.Insert(at, child);
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
            Children.Insert(_contentCount, content);
            _contentCount++;
        }

        public bool HitTest(Point point)
        {
            if (ClipEnabled && !new Rect(ClipLeft, ClipTop, ClipWidth, ClipHeight).Contains(point)) return false;
            return point.X >= 0 && point.Y >= 0 && point.X < W && point.Y < H;
        }

        void Place()
        {
            SetLeft(this, Left - ClipLeft);
            SetTop(this, Top - ClipTop);
        }
    }
}
