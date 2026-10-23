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
            KEY_DOWN = 8192, KEY_UP = 16384;

        public const int POINTER = MOVE | OVER | OUT | DOWN | UP | CLICK | DBL_CLICK | WHEEL
            | RIGHT_DOWN | RIGHT_UP | RIGHT_CLICK | MIDDLE_DOWN | MIDDLE_UP;
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
        int _pressClickCount;
        static ClickState s_click;

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
            _target.AddHandler(InputElement.PointerWheelChangedEvent, (s, e) => Pointer(EventKind.WHEEL, e, e.Delta.Y), bubble, _handledEventsToo);
            // After the UP handler above, so UP comes before CLICK, as in a browser. Handled events
            // too: a press a component cancelled is still the first half of a click.
            _target.AddHandler(InputElement.PointerPressedEvent, (s, e) => PressForClick(e), bubble, true);
            _target.AddHandler(InputElement.PointerReleasedEvent, (s, e) => ReleaseForClick(e), bubble, true);
            _target.AddHandler(InputElement.RightTappedEvent, (s, e) => Pointer(EventKind.RIGHT_CLICK, e), bubble, _handledEventsToo);
            // Keys always bubble on (a TextBox handles most of them itself), as they do in the DOM.
            _target.AddHandler(InputElement.KeyDownEvent, (s, e) => Key(EventKind.KEY_DOWN, e), bubble, true);
            _target.AddHandler(InputElement.KeyUpEvent, (s, e) => Key(EventKind.KEY_UP, e), bubble, true);
        }

        void Pointer(int kind, PointerEventArgs e, double wheelDelta = 0, object nativeEvent = null)
        {
            if (kind == 0 || (_kinds & kind) == 0 || _listener == null) return;
            var position = e.GetPosition(Host.Root);
            var properties = e.GetCurrentPoint(null).Properties;
            var modifiers = e.KeyModifiers;
            _listener.OnPointer(kind, position.X, position.Y, properties.IsLeftButtonPressed,
                modifiers.HasFlag(KeyModifiers.Control), modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt),
                System.Math.Max(-1, System.Math.Min(1, wheelDelta)), nativeEvent ?? e);
        }

        void PressForClick(PointerPressedEventArgs e)
        {
            if (e.GetCurrentPoint(null).Properties.PointerUpdateKind != PointerUpdateKind.LeftButtonPressed) return;
            _pressedHere = true;
            _pressClickCount = e.ClickCount;
        }

        void ReleaseForClick(PointerReleasedEventArgs e)
        {
            if (e.InitialPressMouseButton != MouseButton.Left || !_pressedHere) return;
            _pressedHere = false;
            if (!Inside(e)) return;
            if (s_click == null || s_click.Release != e) s_click = new ClickState { Release = e };
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
                modifiers.HasFlag(KeyModifiers.Control), modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt), 0, e);
        }

        void Key(int kind, KeyEventArgs e)
        {
            if ((_kinds & kind) == 0 || _listener == null) return;
            var modifiers = e.KeyModifiers;
            _listener.OnKey(kind, KeyCodes.FromKey(e.Key),
                modifiers.HasFlag(KeyModifiers.Control), modifiers.HasFlag(KeyModifiers.Shift), modifiers.HasFlag(KeyModifiers.Alt), e);
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

    /// <summary>Avalonia keys as the browser-style key codes HaxeUI uses.</summary>
    public static class KeyCodes
    {
        public static int FromKey(Key key)
        {
            if (key >= Avalonia.Input.Key.A && key <= Avalonia.Input.Key.Z) return 65 + (key - Avalonia.Input.Key.A);
            if (key >= Avalonia.Input.Key.D0 && key <= Avalonia.Input.Key.D9) return 48 + (key - Avalonia.Input.Key.D0);
            if (key >= Avalonia.Input.Key.NumPad0 && key <= Avalonia.Input.Key.NumPad9) return 96 + (key - Avalonia.Input.Key.NumPad0);
            if (key >= Avalonia.Input.Key.F1 && key <= Avalonia.Input.Key.F12) return 112 + (key - Avalonia.Input.Key.F1);
            switch (key)
            {
                case Avalonia.Input.Key.Back: return 8;
                case Avalonia.Input.Key.Tab: return 9;
                case Avalonia.Input.Key.Enter: return 13;
                case Avalonia.Input.Key.LeftShift: case Avalonia.Input.Key.RightShift: return 16;
                case Avalonia.Input.Key.LeftCtrl: case Avalonia.Input.Key.RightCtrl: return 17;
                case Avalonia.Input.Key.LeftAlt: case Avalonia.Input.Key.RightAlt: return 18;
                case Avalonia.Input.Key.Escape: return 27;
                case Avalonia.Input.Key.Space: return 32;
                case Avalonia.Input.Key.PageUp: return 33;
                case Avalonia.Input.Key.PageDown: return 34;
                case Avalonia.Input.Key.End: return 35;
                case Avalonia.Input.Key.Home: return 36;
                case Avalonia.Input.Key.Left: return 37;
                case Avalonia.Input.Key.Up: return 38;
                case Avalonia.Input.Key.Right: return 39;
                case Avalonia.Input.Key.Down: return 40;
                case Avalonia.Input.Key.Insert: return 45;
                case Avalonia.Input.Key.Delete: return 46;
                default: return (int)key;
            }
        }
    }
}
