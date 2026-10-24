using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Documents;
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
            if (_html != null) BuildInlines();
        }

        // ---- HTML text: a small subset, as runs of styled text ----

        string _html;

        /// <summary>
        /// Shows HTML text: b/strong, i/em, u, s/strike/del, br, font (color, size, face) and
        /// span style="color: ...". Other tags are dropped and their text kept; entities are
        /// decoded and whitespace collapses as in HTML. Null goes back to plain Text.
        /// </summary>
        public void SetHtml(string html)
        {
            if (html == _html) return;
            _html = html;
            if (html != null) BuildInlines();
        }

        class RunStyle
        {
            public bool Bold, Italic, Underline, Strike;
            public uint? Color;
            public double? Size;
            public string Face;
            public RunStyle Copy() => (RunStyle)MemberwiseClone();
        }

        static readonly Regex Attribute = new Regex(@"([\w-]+)\s*=\s*(?:""([^""]*)""|'([^']*)'|([^\s>]+))");
        static readonly Regex Space = new Regex(@"\s+");
        static readonly double[] HtmlSizes = { 10, 13, 16, 18, 24, 32, 48 };

        void BuildInlines()
        {
            var inlines = new InlineCollection();
            var style = new RunStyle();
            var open = new List<(string tag, RunStyle before)>();
            var text = new StringBuilder();
            var html = _html;
            void Flush()
            {
                if (text.Length == 0) return;
                var words = System.Net.WebUtility.HtmlDecode(Space.Replace(text.ToString(), " "));
                text.Clear();
                if (words.Length > 0) inlines.Add(MakeRun(words, style));
            }
            var i = 0;
            while (i < html.Length)
            {
                var lt = html.IndexOf('<', i);
                var gt = lt < 0 ? -1 : html.IndexOf('>', lt);
                if (lt < 0 || gt < 0)
                {
                    text.Append(html, i, html.Length - i);
                    break;
                }
                text.Append(html, i, lt - i);
                Flush();
                var tag = html.Substring(lt + 1, gt - lt - 1).Trim();
                i = gt + 1;
                if (tag.StartsWith("/"))
                {
                    var name = tag.Substring(1).Trim().ToLowerInvariant();
                    for (var k = open.Count - 1; k >= 0; k--)
                    {
                        if (open[k].tag != name) continue;
                        style = open[k].before;
                        open.RemoveRange(k, open.Count - k);
                        break;
                    }
                    continue;
                }
                var parts = tag.TrimEnd('/').Split(new[] { ' ', '\t', '\n', '\r' }, 2);
                var tagName = parts[0].ToLowerInvariant();
                if (tagName == "br")
                {
                    inlines.Add(new LineBreak());
                    continue;
                }
                var next = style.Copy();
                var attributes = parts.Length > 1 ? parts[1] : "";
                switch (tagName)
                {
                    case "b": case "strong": next.Bold = true; break;
                    case "i": case "em": next.Italic = true; break;
                    case "u": next.Underline = true; break;
                    case "s": case "strike": case "del": next.Strike = true; break;
                    case "font":
                        foreach (Match m in Attribute.Matches(attributes))
                        {
                            var value = m.Groups[2].Success ? m.Groups[2].Value : m.Groups[3].Success ? m.Groups[3].Value : m.Groups[4].Value;
                            switch (m.Groups[1].Value.ToLowerInvariant())
                            {
                                case "color": next.Color = ParseColor(value) ?? next.Color; break;
                                case "face": next.Face = value; break;
                                case "size":
                                    if (double.TryParse(value.Replace("px", ""), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var size))
                                        next.Size = size >= 1 && size <= 7 && !value.EndsWith("px") ? HtmlSizes[(int)size - 1] : size;
                                    break;
                            }
                        }
                        break;
                    case "span":
                        foreach (Match m in Attribute.Matches(attributes))
                        {
                            if (m.Groups[1].Value.ToLowerInvariant() != "style") continue;
                            var css = m.Groups[2].Success ? m.Groups[2].Value : m.Groups[3].Success ? m.Groups[3].Value : m.Groups[4].Value;
                            var colour = Regex.Match(css, @"(?:^|;)\s*color\s*:\s*([^;]+)");
                            if (colour.Success) next.Color = ParseColor(colour.Groups[1].Value.Trim()) ?? next.Color;
                        }
                        break;
                    default:
                        continue; // unknown: dropped, its text kept
                }
                open.Add((tagName, style));
                style = next;
            }
            Flush();
            Inlines = inlines;
        }

        Run MakeRun(string text, RunStyle style)
        {
            var run = new Run(text);
            if (style.Bold) run.FontWeight = FontWeight.Bold;
            if (style.Italic) run.FontStyle = FontStyle.Italic;
            if (style.Underline || style.Strike) run.TextDecorations = UIFonts.Decorations(style.Underline, style.Strike);
            if (style.Color.HasValue) run.Foreground = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, style.Color.Value)));
            if (style.Size.HasValue) run.FontSize = style.Size.Value;
            if (!string.IsNullOrEmpty(style.Face)) run.FontFamily = UIFonts.ResolveFamily(style.Face);
            return run;
        }

        static uint? ParseColor(string value)
        {
            var hex = value.Trim().TrimStart('#');
            if (hex.Length == 3) hex = new string(new[] { hex[0], hex[0], hex[1], hex[1], hex[2], hex[2] });
            return hex.Length == 6 && uint.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out var rgb) ? 0xFF000000u | rgb : (uint?)null;
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
            if (_html != null)
            {
                Width = double.NaN;
                Height = double.NaN;
                Measure(new Size(maxWidth > 0 ? maxWidth : double.PositiveInfinity, double.PositiveInfinity));
                MeasuredWidth = System.Math.Ceiling(DesiredSize.Width);
                MeasuredHeight = System.Math.Ceiling(DesiredSize.Height);
                Width = width;
                Height = height;
                return;
            }
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
