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

    /// <summary>What the host tells the HaxeUI side about the window's life.</summary>
    public interface IHostListener
    {
        void OnReady();
        void OnResize(double width, double height);
        void OnClosed();
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

        public static Window Window { get; private set; }
        public static UIPanel Root { get; private set; }

        public static string Title
        {
            get => Window != null ? Window.Title : _title;
            set
            {
                _title = value ?? "";
                if (Window != null) Window.Title = _title;
            }
        }

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
                Background = Brushes.White,
            };
            Root = new UIPanel();
            window.Content = Root;
            window.PropertyChanged += (s, e) =>
            {
                if (e.Property == TopLevel.ClientSizeProperty)
                    Listener?.OnResize(window.ClientSize.Width, window.ClientSize.Height);
            };
            window.Closed += (s, e) => Listener?.OnClosed();
            Window = window;
            return window;
        }

        public static void Post(ICallback callback)
        {
            Dispatcher.UIThread.Post(() => callback.Invoke());
        }

        public static object StartTimer(int milliseconds, ICallback callback)
        {
            var timer = new DispatcherTimer(TimeSpan.FromMilliseconds(System.Math.Max(1, milliseconds)), DispatcherPriority.Normal, (s, e) => callback.Invoke());
            timer.Start();
            return timer;
        }

        public static void StopTimer(object handle)
        {
            (handle as DispatcherTimer)?.Stop();
        }

        public static void CloseWindow()
        {
            Window?.Close();
        }

        public static void Exit(int code)
        {
            Environment.Exit(code);
        }
    }
}
