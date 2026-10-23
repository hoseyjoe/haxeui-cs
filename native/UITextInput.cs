using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace HaxeUICs
{
    /// <summary>What a UITextInput tells the HaxeUI side.</summary>
    public interface ITextInputListener
    {
        void OnTextChanged();
        void OnScrollChanged();
        void OnFocus(bool focused);
    }

    /// <summary>
    /// A HaxeUI text input: an Avalonia TextBox with its own chrome stripped (HaxeUI's style paints
    /// the field around it) and its scrollbars hidden (HaxeUI draws those too). Pointer and key
    /// events keep bubbling to the owning component, as an HTML input's do.
    /// </summary>
    public class UITextInput : TextBox
    {
        ITextInputListener _listener;
        ScrollViewer _scroll;
        bool _settingText;

        // Use TextBox's control theme: a subclass would otherwise get no template at all.
        protected override System.Type StyleKeyOverride => typeof(TextBox);

        public UITextInput()
        {
            Background = Brushes.Transparent;
            BorderThickness = new Thickness(0);
            Padding = new Thickness(0);
            MinWidth = 0;
            MinHeight = 0;
            IsTabStop = false; // HaxeUI's FocusManager owns tab order
            NewLine = "\n";
            VerticalContentAlignment = VerticalAlignment.Top;
            ScrollViewer.SetHorizontalScrollBarVisibility(this, ScrollBarVisibility.Hidden);
            ScrollViewer.SetVerticalScrollBarVisibility(this, ScrollBarVisibility.Hidden);

            PropertyChanged += (s, e) =>
            {
                if (e.Property == TextProperty && !_settingText) _listener?.OnTextChanged();
            };
            GotFocus += (s, e) => _listener?.OnFocus(true);
            LostFocus += (s, e) => _listener?.OnFocus(false);
        }

        public void SetListener(ITextInputListener listener)
        {
            _listener = listener;
        }

        /// <summary>Sets the text from code: no OnTextChanged, so HaxeUI never hears its own write.</summary>
        public void SetText(string text)
        {
            text ??= "";
            if (Text == text) return;
            _settingText = true;
            try { Text = text; }
            finally { _settingText = false; }
        }

        public bool IsPassword => PasswordChar != '\0';

        public void SetMultiline(bool multiline) => AcceptsReturn = multiline;
        public void SetWordWrap(bool wrap)
        {
            TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap;
            // A hidden scrollbar still lets the text be as wide as it likes, so it never wraps;
            // a disabled one holds it to the box's width.
            ScrollViewer.SetHorizontalScrollBarVisibility(this, wrap ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Hidden);
        }
        public void SetPassword(bool password) => PasswordChar = password ? '•' : '\0';
        public void SetSelectionColor(uint argb) => SelectionBrush = new SolidColorBrush(Color.FromUInt32(argb));

        public void SetFont(string family, double size, bool bold, bool italic, bool underline)
        {
            FontFamily = UIFonts.ResolveFamily(family);
            FontSize = size > 0 ? size : 13;
            FontWeight = bold ? FontWeight.Bold : FontWeight.Normal;
            FontStyle = italic ? FontStyle.Italic : FontStyle.Normal;
        }

        public void SetColor(uint argb)
        {
            var brush = new SolidColorBrush(Color.FromUInt32(argb));
            Foreground = brush;
            CaretBrush = brush;
        }

        /// <summary>0 left, 1 center, 2 right.</summary>
        public void SetAlign(int align)
        {
            TextAlignment = align == 1 ? TextAlignment.Center : align == 2 ? TextAlignment.Right : TextAlignment.Left;
        }

        /// <summary>A shadow of the glyphs (haxeui-cs's text-shadow); argb 0 removes it.</summary>
        public void SetShadow(double dx, double dy, double blur, uint argb)
        {
            Effect = argb == 0 ? null : new DropShadowEffect
            {
                OffsetX = dx,
                OffsetY = dy,
                BlurRadius = System.Math.Max(0, blur),
                Color = Color.FromUInt32(argb | 0xFF000000u),
                Opacity = ((argb >> 24) & 0xFF) / 255.0,
            };
        }

        /// <summary>Sets position and size; NaN leaves that value as it was.</summary>
        public void SetBounds(double left, double top, double width, double height)
        {
            if (!double.IsNaN(left)) Canvas.SetLeft(this, left);
            if (!double.IsNaN(top)) Canvas.SetTop(this, top);
            if (!double.IsNaN(width)) Width = System.Math.Max(0, width);
            if (!double.IsNaN(height)) Height = System.Math.Max(0, height);
        }

        public double ScrollX => _scroll?.Offset.X ?? 0;
        public double ScrollY => _scroll?.Offset.Y ?? 0;
        public double ExtentWidth => _scroll?.Extent.Width ?? 0;
        public double ExtentHeight => _scroll?.Extent.Height ?? 0;
        public double ViewportWidth => _scroll?.Viewport.Width ?? 0;
        public double ViewportHeight => _scroll?.Viewport.Height ?? 0;

        public void SetScroll(double x, double y)
        {
            if (_scroll != null && (_scroll.Offset.X != x || _scroll.Offset.Y != y)) _scroll.Offset = new Vector(x, y);
        }

        public void Blur()
        {
            if (IsFocused) TopLevel.GetTopLevel(this)?.FocusManager?.Focus(null, NavigationMethod.Unspecified, KeyModifiers.None);
        }

        protected override void OnApplyTemplate(TemplateAppliedEventArgs e)
        {
            base.OnApplyTemplate(e);
            _scroll = e.NameScope.Find<ScrollViewer>("PART_ScrollViewer");
            if (_scroll != null) _scroll.ScrollChanged += (s, a) => _listener?.OnScrollChanged();
        }

        protected override void OnPointerPressed(PointerPressedEventArgs e)
        {
            base.OnPointerPressed(e);
            e.Handled = false; // the owning component still hears the press (it is what focuses it in HaxeUI)
        }

        protected override void OnPointerReleased(PointerReleasedEventArgs e)
        {
            base.OnPointerReleased(e);
            e.Handled = false;
        }
    }
}
