// Haxe emits its top-level classes (Array, Math, Date, Std, Type...) into the global
// namespace, where they shadow System's: always write System.Math, System.Array, etc.
using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Media;
using Avalonia.Themes.Simple;
using Avalonia.Threading;
#if HAXEUI_CS_HEADLESS
using Avalonia.Headless;
#endif

namespace HaxeUICs
{
    /// <summary>A parameterless callback Haxe can implement (Haxe functions are not .NET delegates).</summary>
    public interface ICallback
    {
        void Invoke();
    }

    /// <summary>Runs Haxe's own event loop once; answers how long until it next needs to (ms, -1: no idea).</summary>
    public interface IEventsPump
    {
        double Pump();
    }

    /// <summary>What the host tells the HaxeUI side about the window's life.</summary>
    public interface IHostListener
    {
        void OnReady();
        void OnResize(double width, double height);
        void OnClosed();
    }

    /// <summary>Asked before a close the app did not ask for: false keeps the window open.</summary>
    public interface ICloseListener
    {
        bool OnCloseRequested();
    }

    public class HostApplication : Application
    {
        public override void Initialize()
        {
            // Window chrome and TextBox templates come from a theme; HaxeUI paints everything else itself.
            Styles.Add(new SimpleTheme());
        }

        public override void OnFrameworkInitializationCompleted()
        {
            if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            {
                desktop.ShutdownMode = ShutdownMode.OnMainWindowClose;
                var window = Host.CreateWindow();
                window.Opened += (s, e) => Host.Listener.OnReady();
                desktop.MainWindow = window;
            }
            base.OnFrameworkInitializationCompleted();
        }
    }

    /// <summary>The Avalonia application, its one window and its dispatcher, as HaxeUI needs them.</summary>
    public static class Host
    {
        internal static IHostListener Listener;
        static string _title = "";
        static int _width = 800;
        static int _height = 600;
        static bool _resizable = true;
        static int _minWidth, _minHeight;
        static bool _maximized;
        static byte[] _icon;

        public static Window Window { get; private set; }

        static UIPanel _root;

        /// <summary>
        /// The panel root components live in. It exists before the window does, so components added
        /// early (HaxeUIApp's preloader) are already there when the window takes it as its content.
        /// </summary>
        public static UIPanel Root => _root ??= new UIPanel();

        public static string Title
        {
            get => Window != null ? Window.Title : _title;
            set
            {
                _title = value ?? "";
                if (Window != null) Window.Title = _title;
            }
        }

        static int _screenKinds;
        static IPanelListener _screenListener;
        static EventRouter _screenEvents;

        /// <summary>
        /// Window-wide input for HaxeUI's Screen: hears events even after a component handled them.
        /// May be called before the window exists (Toolkit.init does); it attaches on creation.
        /// </summary>
        public static void ListenScreen(int kinds, IPanelListener listener)
        {
            _screenKinds = kinds;
            _screenListener = listener;
            _screenEvents?.Update(kinds, listener);
        }

        /// <summary>Window options beyond size and title; kept until the window exists.</summary>
        public static void ConfigureWindow(bool resizable, int minWidth, int minHeight, bool maximized)
        {
            _resizable = resizable;
            _minWidth = System.Math.Max(0, minWidth);
            _minHeight = System.Math.Max(0, minHeight);
            _maximized = maximized;
            if (Window != null) ApplyOptions(Window);
        }

        static void ApplyOptions(Window window)
        {
            window.CanResize = _resizable;
            window.MinWidth = _minWidth;
            window.MinHeight = _minHeight;
            if (_maximized) window.WindowState = WindowState.Maximized;
            if (_icon != null)
            {
                try { window.Icon = new WindowIcon(new System.IO.MemoryStream(_icon)); }
                catch (System.Exception) { } // not an image: no icon
            }
        }

        /// <summary>The window's icon, from image bytes (PNG and the like).</summary>
        public static void SetIcon(byte[] image)
        {
            _icon = image;
            if (Window != null) ApplyOptions(Window);
        }

        public static bool HasIcon => Window?.Icon != null;
        public static bool IsResizable => Window?.CanResize ?? _resizable;
        public static double MinWidth => Window?.MinWidth ?? _minWidth;
        public static double MinHeight => Window?.MinHeight ?? _minHeight;
        public static bool IsMaximized => Window != null ? Window.WindowState == WindowState.Maximized : _maximized;

        public static double ClientWidth => Window != null ? Window.ClientSize.Width : _width;
        public static double ClientHeight => Window != null ? Window.ClientSize.Height : _height;

        /// <summary>Starts Avalonia with a desktop window; blocks until that window closes.</summary>
        public static void RunDesktop(IHostListener listener, string title, int width, int height)
        {
            Listener = listener;
            _title = title ?? "";
            _width = width;
            _height = height;
            AppBuilder.Configure<HostApplication>()
                .UsePlatformDetect()
                .StartWithClassicDesktopLifetime(System.Array.Empty<string>());
        }

#if HAXEUI_CS_HEADLESS
        /// <summary>Starts Avalonia headless (real Skia drawing, no OS window); returns once ready.</summary>
        public static void StartHeadless(IHostListener listener, int width, int height)
        {
            Listener = listener;
            _width = width;
            _height = height;
            AppBuilder.Configure<HostApplication>()
                .UseSkia()
                .UseHeadless(new AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false })
                .SetupWithoutStarting();
            var window = CreateWindow();
            window.Show();
            Dispatcher.UIThread.RunJobs();
            listener.OnReady();
        }
#endif

        internal static Window CreateWindow()
        {
            var window = new Window
            {
                Title = _title,
                Width = _width,
                Height = _height,
                Background = new SolidColorBrush(Color.FromUInt32(_background)),
            };
            window.Content = Root;
            ApplyOptions(window);
            window.PropertyChanged += (s, e) =>
            {
                if (e.Property == TopLevel.ClientSizeProperty)
                    Listener?.OnResize(window.ClientSize.Width, window.ClientSize.Height);
            };
            window.Closing += (s, e) =>
            {
                if (_closeByApp) return;
                if (!AskClose()) e.Cancel = true;
                WakeEventsPump(); // the handler may have started work (a prompt) of its own
            };
            window.Closed += (s, e) => Listener?.OnClosed();
            _screenEvents = new EventRouter(window, true);
            _screenEvents.Update(_screenKinds, _screenListener);
            Window = window;
            return window;
        }

        /// <summary>
        /// Toolkit.scale: the root panel, and so every root component and popup, drawn this much
        /// larger from the window's top left. Pointer positions measured against the root stay in
        /// HaxeUI's units, and text and images render at the scaled size, not stretched.
        /// </summary>
        public static void SetScale(double scaleX, double scaleY)
        {
            if (scaleX <= 0 || scaleY <= 0) return;
            Root.RenderTransformOrigin = new RelativePoint(0, 0, RelativeUnit.Absolute);
            Root.RenderTransform = scaleX == 1 && scaleY == 1 ? null : new ScaleTransform(scaleX, scaleY);
        }

        /// <summary>
        /// What shows behind the components, as 0xAARRGGBB (white until the app says otherwise): an
        /// app's dark theme sets it, as html5 sets the page's and Heaps the engine's clear colour.
        /// Kept until the window exists.
        /// </summary>
        public static void SetBackground(uint argb)
        {
            _background = argb;
            if (Window != null) Window.Background = new SolidColorBrush(Color.FromUInt32(argb));
        }

        static uint _background = 0xFFFFFFFF;

        /// <summary>The cursor the whole window shows (a splitter drag), or null for none.</summary>
        public static string ScreenCursorName { get; private set; }

        public static void SetScreenCursor(string css)
        {
            ScreenCursorName = css;
            if (Window != null) Window.Cursor = UIStyle.CursorFor(css);
        }

        public static void Post(ICallback callback)
        {
            Dispatcher.UIThread.Post(() =>
            {
                callback.Invoke();
                WakeEventsPump();
            });
        }

        /// <summary>
        /// Runs the callback with the next frame, as a browser's requestAnimationFrame: work that
        /// re-schedules itself (HaxeUI's animations) then advances once per frame instead of spinning.
        /// Before the window exists it is simply queued.
        /// </summary>
        public static void NextFrame(ICallback callback)
        {
            _frameQueue.Add(callback);
            if (_frameTimer == null)
                _frameTimer = new DispatcherTimer(System.TimeSpan.FromMilliseconds(FrameMilliseconds), DispatcherPriority.Normal, (s, e) => RunFrame());
            if (!_frameTimer.IsEnabled) _frameTimer.Start();
        }

        const int FrameMilliseconds = 16;
        static System.Collections.Generic.List<ICallback> _frameQueue = new System.Collections.Generic.List<ICallback>();
        static DispatcherTimer _frameTimer;

        /// <summary>Runs one frame's batch; anything queued while it runs waits for the next frame.</summary>
        internal static void RunFrame()
        {
            if (_frameQueue.Count == 0)
            {
                _frameTimer?.Stop();
                return;
            }
            var batch = _frameQueue;
            _frameQueue = new System.Collections.Generic.List<ICallback>();
            foreach (var callback in batch)
            {
                // Each on its own, as a browser runs requestAnimationFrame callbacks: one that throws
                // is reported and the rest of its frame still runs.
                try { callback.Invoke(); }
                catch (System.Exception e) { System.Console.Error.WriteLine("haxeui-cs: a callLater threw: " + e); }
            }
            WakeEventsPump();
        }

        // Haxe's event loop (haxe.Timer, haxe.MainLoop, results posted from other threads) gets a
        // turn when it says it next needs one, and straight after anything that may have given it
        // work (a HaxeUI frame, input, a posted callback). With nothing scheduled it is polled
        // slowly, for work posted from other threads: an idle app is not woken 100 times a second.
        const double IdleEventsPollMs = 250;
        static IEventsPump _eventsPump;
        static DispatcherTimer _eventsTimer;

        /// <summary>How often the Haxe event loop has been pumped (for the idle check).</summary>
        public static int EventsPumps { get; private set; }

        public static void StartEventsPump(IEventsPump pump)
        {
            _eventsPump = pump;
            _eventsTimer = new DispatcherTimer(TimeSpan.FromMilliseconds(1), DispatcherPriority.Normal, (s, e) => PumpEvents());
            _eventsTimer.Start();
        }

        static void PumpEvents()
        {
            EventsPumps++;
            var next = _eventsPump.Pump();
            var wait = next < 0 ? IdleEventsPollMs : System.Math.Clamp(next, 1, IdleEventsPollMs);
            _eventsTimer.Interval = TimeSpan.FromMilliseconds(wait);
        }

        /// <summary>Gives the Haxe event loop a turn as soon as the dispatcher is free.</summary>
        internal static void WakeEventsPump()
        {
            if (_eventsTimer == null || _eventsTimer.Interval.TotalMilliseconds <= 1) return;
            _eventsTimer.Stop();
            _eventsTimer.Interval = TimeSpan.FromMilliseconds(1);
            _eventsTimer.Start();
        }

        public static object StartTimer(int milliseconds, ICallback callback)
        {
            var timer = new DispatcherTimer(TimeSpan.FromMilliseconds(System.Math.Max(1, milliseconds)), DispatcherPriority.Normal, (s, e) =>
            {
                callback.Invoke();
                WakeEventsPump();
            });
            timer.Start();
            return timer;
        }

        public static void StopTimer(object handle)
        {
            (handle as DispatcherTimer)?.Stop();
        }

        /// <summary>Renders the window's content as it stands to a PNG; false when there is no window yet.</summary>
        public static bool CaptureWindow(string path)
        {
            if (Window == null || Root == null) return false;
            var size = new PixelSize(System.Math.Max(1, (int)ClientWidth), System.Math.Max(1, (int)ClientHeight));
            using var bitmap = new Avalonia.Media.Imaging.RenderTargetBitmap(size);
            bitmap.Render(Window);
            bitmap.Save(path);
            return true;
        }

        /// <summary>
        /// What a close the app did not ask for (the close button, Alt+F4) consults; null lets
        /// every close through. A close by CloseWindow (app.exit()) never asks it.
        /// </summary>
        public static ICloseListener CloseListener { get; set; }

        static bool _closeByApp;

        /// <summary>
        /// Whether the window may close now, as the close listener answers. One that throws is
        /// reported and the window closes: an app's bug never makes a window that can't be closed.
        /// </summary>
        public static bool AskClose()
        {
            var listener = CloseListener;
            if (listener == null) return true;
            try { return listener.OnCloseRequested(); }
            catch (System.Exception e)
            {
                System.Console.Error.WriteLine("haxeui-cs: a close request handler threw: " + e);
                return true;
            }
        }

        public static void CloseWindow()
        {
            if (Window == null) return;
            _closeByApp = true;
            Window.Close();
        }

        public static void Exit(int code)
        {
            UIClipboard.Flush(); // what the app copied stays on the clipboard after it ends, as in any program
            Environment.Exit(code);
        }
    }
}
