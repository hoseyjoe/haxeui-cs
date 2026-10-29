using Avalonia;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Rendering;

namespace HaxeUICs
{
    /// <summary>Bit flags naming the input events a listener wants; mirrored by haxe.ui.backend.cs.EventMapper.</summary>
    public static class EventKind
    {
        public const int MOVE = 1, OVER = 2, OUT = 4, DOWN = 8, UP = 16, CLICK = 32, DBL_CLICK = 64, WHEEL = 128,
            RIGHT_DOWN = 256, RIGHT_UP = 512, RIGHT_CLICK = 1024, MIDDLE_DOWN = 2048, MIDDLE_UP = 4096,
            KEY_DOWN = 8192, KEY_UP = 16384, MIDDLE_CLICK = 32768, KEY_PRESS = 65536;

        public const int POINTER = MOVE | OVER | OUT | DOWN | UP | CLICK | DBL_CLICK | WHEEL
            | RIGHT_DOWN | RIGHT_UP | RIGHT_CLICK | MIDDLE_DOWN | MIDDLE_UP | MIDDLE_CLICK;
    }

    /// <summary>
    /// Receives input for a panel (or the whole window). Positions are in window coordinates;
    /// nativeEvent is the Avalonia event, which NativeEvents.Cancel can stop from bubbling further.
    /// </summary>
    public interface IPanelListener
    {
        void OnPointer(int kind, double screenX, double screenY, bool buttonDown, bool ctrl, bool shift, bool alt, double wheelDelta, object nativeEvent);
        void OnKey(int kind, int keyCode, bool ctrl, bool shift, bool alt, object nativeEvent);
    }

    public static class NativeEvents
    {
        /// <summary>HaxeUI's event.cancel(): the event stops here, as DOM stopPropagation does.</summary>
        public static void Cancel(object nativeEvent)
        {
            if (nativeEvent is ClickState click) click.Cancelled = true;
            else if (nativeEvent is RoutedEventArgs routed) routed.Handled = true;
        }
    }

    /// <summary>One click as it bubbles from element to element: cancelling it stops the rest.</summary>
    internal class ClickState
    {
        public PointerReleasedEventArgs Release;
        public bool Cancelled;
    }

    /// <summary>
    /// Subscribes once to every input event of one element and forwards those its listener wants.
    /// Events bubble natively, as in the DOM: each ancestor listening for a kind hears it too.
    /// </summary>
    internal class EventRouter
    {
        readonly Interactive _target;
        readonly bool _handledEventsToo;
        bool _attached;
        int _kinds;
        IPanelListener _listener;

        // Clicks are made here as a browser makes them: a left press and release inside this
        // element is a click, EVERY time, and the second press inside the double-click time also
        // makes a double click. Avalonia's Tapped is not used: it swallows that second click.
        bool _pressedHere;
        bool _middlePressedHere;
        int _pressClickCount;
        static ClickState s_click;

        // Set during a press that turned into something else (a long press showing a tooltip):
        // its release makes no click. Cleared by the next press.
        static bool s_suppressClick;

        /// <summary>The press under way makes no CLICK (or DBL_CLICK) when it is released.</summary>
        internal static void SuppressNextClick() => s_suppressClick = true;

        public EventRouter(Interactive target, bool handledEventsToo)
        {
            _target = target;
            _handledEventsToo = handledEventsToo;
        }

        public void Update(int kinds, IPanelListener listener)
        {
            _kinds = kinds;
            _listener = listener;
            if (kinds != 0 && !_attached) Attach();
        }

        void Attach()
        {
            _attached = true;
            const RoutingStrategies bubble = RoutingStrategies.Bubble | RoutingStrategies.Direct;
            _target.AddHandler(InputElement.PointerMovedEvent, (s, e) => Pointer(EventKind.MOVE, e), bubble, _handledEventsToo);
            _target.AddHandler(InputElement.PointerEnteredEvent, (s, e) => Pointer(EventKind.OVER, e), RoutingStrategies.Direct, _handledEventsToo);
            _target.AddHandler(InputElement.PointerExitedEvent, (s, e) => Pointer(EventKind.OUT, e), RoutingStrategies.Direct, _handledEventsToo);
            _target.AddHandler(InputElement.PointerPressedEvent, (s, e) => Pointer(PressKind(e), e), bubble, _handledEventsToo);
            _target.AddHandler(InputElement.PointerReleasedEvent, (s, e) => Pointer(ReleaseKind(e), e), bubble, _handledEventsToo);
            _target.AddHandler(InputElement.PointerWheelChangedEvent, (s, e) => Wheel(e), bubble, _handledEventsToo);
            // After the UP handler above, so UP comes before CLICK, as in a browser. Handled events
            // too: a press a component cancelled is still the first half of a click.
            _target.AddHandler(InputElement.PointerPressedEvent, (s, e) => PressForClick(e), bubble, true);
            _target.AddHandler(InputElement.PointerReleasedEvent, (s, e) => ReleaseForClick(e), bubble, true);
            _target.AddHandler(InputElement.RightTappedEvent, (s, e) => Pointer(EventKind.RIGHT_CLICK, e), bubble, _handledEventsToo);
            // Keys always bubble on (a TextBox handles most of them itself), as they do in the DOM.
            _target.AddHandler(InputElement.KeyDownEvent, (s, e) => Key(EventKind.KEY_DOWN, e), bubble, true);
            _target.AddHandler(InputElement.KeyUpEvent, (s, e) => Key(EventKind.KEY_UP, e), bubble, true);
            // Text the keyboard produces: KEY_PRESS, as heaps maps it (a browser's keypress).
            _target.AddHandler(InputElement.TextInputEvent, (s, e) => KeyPress(e), bubble, true);
        }

        void Pointer(int kind, PointerEventArgs e, double wheelDelta = 0, object nativeEvent = null, bool shift = false)
        {
            if (kind == 0 || (_kinds & kind) == 0 || _listener == null) return;
            var position = e.GetPosition(Host.Root);
            var properties = e.GetCurrentPoint(null).Properties;
            var modifiers = e.KeyModifiers;
            _listener.OnPointer(kind, position.X, position.Y, properties.IsLeftButtonPressed,
                KeyCodes.IsCtrl((int)modifiers, System.OperatingSystem.IsMacOS()), shift || modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt),
                System.Math.Max(-1, System.Math.Min(1, wheelDelta)), nativeEvent ?? e);
            Host.WakeEventsPump(); // a handler may have started a haxe.Timer
        }

        /// <summary>
        /// A sideways wheel (or a trackpad's sideways swipe) is shift+wheel, which is how HaxeUI's
        /// ScrollView scrolls across: MouseEvent has no horizontal delta of its own.
        /// </summary>
        void Wheel(PointerWheelEventArgs e)
        {
            if (e.Delta.Y == 0 && e.Delta.X != 0) Pointer(EventKind.WHEEL, e, e.Delta.X, null, true);
            else Pointer(EventKind.WHEEL, e, e.Delta.Y);
        }

        void PressForClick(PointerPressedEventArgs e)
        {
            var kind = e.GetCurrentPoint(null).Properties.PointerUpdateKind;
            if (kind == PointerUpdateKind.MiddleButtonPressed) _middlePressedHere = true;
            if (kind != PointerUpdateKind.LeftButtonPressed) return;
            s_suppressClick = false;
            _pressedHere = true;
            _pressClickCount = e.ClickCount;
        }

        void ReleaseForClick(PointerReleasedEventArgs e)
        {
            if (e.InitialPressMouseButton == MouseButton.Middle && _middlePressedHere)
            {
                // a middle press and release inside is a MIDDLE_CLICK, as a left pair is a CLICK
                _middlePressedHere = false;
                if (Inside(e)) Pointer(EventKind.MIDDLE_CLICK, e);
                return;
            }
            if (e.InitialPressMouseButton != MouseButton.Left || !_pressedHere) return;
            _pressedHere = false;
            if (!Inside(e)) return;
            if (s_click == null || s_click.Release != e) s_click = new ClickState { Release = e, Cancelled = s_suppressClick };
            var click = s_click;
            if (click.Cancelled) return;
            Pointer(EventKind.CLICK, e, 0, click);
            if (_pressClickCount == 2 && !click.Cancelled) Pointer(EventKind.DBL_CLICK, e, 0, click);
        }

        /// <summary>Released over this element (its own hit test, clip included): the click is its.</summary>
        bool Inside(PointerEventArgs e)
        {
            if (!(_target is Visual visual)) return true;
            var p = e.GetPosition(visual);
            if (_target is ICustomHitTest custom) return custom.HitTest(p);
            return new Rect(visual.Bounds.Size).Contains(p);
        }

        void Pointer(int kind, TappedEventArgs e)
        {
            if ((_kinds & kind) == 0 || _listener == null) return;
            var position = e.GetPosition(Host.Root);
            var modifiers = e.KeyModifiers;
            _listener.OnPointer(kind, position.X, position.Y, false,
                KeyCodes.IsCtrl((int)modifiers, System.OperatingSystem.IsMacOS()), modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt), 0, e);
        }

        void Key(int kind, KeyEventArgs e)
        {
            if ((_kinds & kind) == 0 || _listener == null) return;
            var modifiers = e.KeyModifiers;
            _listener.OnKey(kind, KeyCodes.FromKey(e.Key),
                KeyCodes.IsCtrl((int)modifiers, System.OperatingSystem.IsMacOS()), modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt), e);
            Host.WakeEventsPump();
        }

        void KeyPress(TextInputEventArgs e)
        {
            if ((_kinds & EventKind.KEY_PRESS) == 0 || _listener == null || string.IsNullOrEmpty(e.Text)) return;
            _listener.OnKey(EventKind.KEY_PRESS, char.ConvertToUtf32(e.Text, 0), false, false, false, e);
        }

        static int PressKind(PointerPressedEventArgs e)
        {
            switch (e.GetCurrentPoint(null).Properties.PointerUpdateKind)
            {
                case PointerUpdateKind.LeftButtonPressed: return EventKind.DOWN;
                case PointerUpdateKind.RightButtonPressed: return EventKind.RIGHT_DOWN;
                case PointerUpdateKind.MiddleButtonPressed: return EventKind.MIDDLE_DOWN;
                default: return 0;
            }
        }

        static int ReleaseKind(PointerReleasedEventArgs e)
        {
            switch (e.InitialPressMouseButton)
            {
                case MouseButton.Left: return EventKind.UP;
                case MouseButton.Right: return EventKind.RIGHT_UP;
                case MouseButton.Middle: return EventKind.MIDDLE_UP;
                default: return 0;
            }
        }
    }

    /// <summary>
    /// Avalonia keys as the browser's key codes, which HaxeUI and its apps compare against.
    /// Avalonia's own Key values are WPF's enum, not key codes: a key with no browser code is 0.
    /// </summary>
    public static class KeyCodes
    {
        /// <summary>
        /// Whether these KeyModifiers (as an int) count as Ctrl. On a Mac, Cmd does: HaxeUI's
        /// KeyboardEvent has no meta key, and an app's Ctrl shortcuts are Cmd shortcuts there.
        /// </summary>
        public static bool IsCtrl(int modifiers, bool isMac)
        {
            var m = (KeyModifiers)modifiers;
            return m.HasFlag(KeyModifiers.Control) || (isMac && m.HasFlag(KeyModifiers.Meta));
        }

        public static int FromKey(Key key)
        {
            if (key >= Key.A && key <= Key.Z) return 65 + (key - Key.A);
            if (key >= Key.D0 && key <= Key.D9) return 48 + (key - Key.D0);
            if (key >= Key.NumPad0 && key <= Key.NumPad9) return 96 + (key - Key.NumPad0);
            if (key >= Key.F1 && key <= Key.F24) return 112 + (key - Key.F1);
            switch (key)
            {
                case Key.Cancel: return 3;
                case Key.Back: return 8;
                case Key.Tab: return 9;
                case Key.Clear: return 12;
                case Key.Enter: return 13;
                case Key.LeftShift: case Key.RightShift: return 16;
                case Key.LeftCtrl: case Key.RightCtrl: return 17;
                case Key.LeftAlt: case Key.RightAlt: return 18;
                case Key.Pause: return 19;
                case Key.CapsLock: return 20;
                case Key.KanaMode: return 21;
                case Key.JunjaMode: return 23;
                case Key.FinalMode: return 24;
                case Key.HanjaMode: return 25;
                case Key.Escape: return 27;
                case Key.ImeConvert: return 28;
                case Key.ImeNonConvert: return 29;
                case Key.ImeAccept: return 30;
                case Key.ImeModeChange: return 31;
                case Key.Space: return 32;
                case Key.PageUp: return 33;
                case Key.PageDown: return 34;
                case Key.End: return 35;
                case Key.Home: return 36;
                case Key.Left: return 37;
                case Key.Up: return 38;
                case Key.Right: return 39;
                case Key.Down: return 40;
                case Key.Select: return 41;
                case Key.Print: return 42;
                case Key.Execute: return 43;
                case Key.PrintScreen: return 44;
                case Key.Insert: return 45;
                case Key.Delete: return 46;
                case Key.Help: return 47;
                case Key.LWin: return 91;
                case Key.RWin: return 92;
                case Key.Apps: return 93;
                case Key.Sleep: return 95;
                case Key.Multiply: return 106;
                case Key.Add: return 107;
                case Key.Separator: return 108;
                case Key.Subtract: return 109;
                case Key.Decimal: return 110;
                case Key.Divide: return 111;
                case Key.NumLock: return 144;
                case Key.Scroll: return 145;
                case Key.BrowserBack: return 166;
                case Key.BrowserForward: return 167;
                case Key.BrowserRefresh: return 168;
                case Key.BrowserStop: return 169;
                case Key.BrowserSearch: return 170;
                case Key.BrowserFavorites: return 171;
                case Key.BrowserHome: return 172;
                case Key.VolumeMute: return 173;
                case Key.VolumeDown: return 174;
                case Key.VolumeUp: return 175;
                case Key.MediaNextTrack: return 176;
                case Key.MediaPreviousTrack: return 177;
                case Key.MediaStop: return 178;
                case Key.MediaPlayPause: return 179;
                case Key.LaunchMail: return 180;
                case Key.SelectMedia: return 181;
                case Key.LaunchApplication1: return 182;
                case Key.LaunchApplication2: return 183;
                case Key.OemSemicolon: return 186;
                case Key.OemPlus: return 187;
                case Key.OemComma: return 188;
                case Key.OemMinus: return 189;
                case Key.OemPeriod: return 190;
                case Key.OemQuestion: return 191;
                case Key.OemTilde: return 192;
                case Key.AbntC1: return 193;
                case Key.AbntC2: return 194;
                case Key.OemOpenBrackets: return 219;
                case Key.OemPipe: return 220;
                case Key.OemCloseBrackets: return 221;
                case Key.OemQuotes: return 222;
                case Key.Oem8: return 223;
                case Key.OemBackslash: return 226;
                case Key.ImeProcessed: return 229;
                case Key.Attn: return 246;
                case Key.CrSel: return 247;
                case Key.ExSel: return 248;
                case Key.EraseEof: return 249;
                case Key.Play: return 250;
                case Key.Zoom: return 251;
                case Key.Pa1: return 253;
                case Key.OemClear: return 254;
                default: return 0;
            }
        }
    }
}
