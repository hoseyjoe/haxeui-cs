#if HAXEUI_CS_HEADLESS
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Headless;
using Avalonia.Input;
using Avalonia.Platform;
using Avalonia.Threading;

namespace HaxeUICs
{
    /// <summary>
    /// Drives the headless host for tests: runs queued work and render ticks, injects input and
    /// captures frames. Haxe reaches it through haxe.ui.backend.cs.TestDriver.
    /// </summary>
    public static class HeadlessDriver
    {
        public static void Pump(int frames)
        {
            for (var i = 0; i < frames; i++)
            {
                RunLoopOnce();
                Host.RunFrame(); // one HaxeUI frame (callLater batch) per pump, whatever the wall clock did
                AvaloniaHeadlessPlatform.ForceRenderTimerTick();
                Dispatcher.UIThread.RunJobs();
            }
        }

        /// <summary>
        /// One pass of the real dispatcher loop: RunJobs alone never promotes due DispatcherTimers,
        /// the main loop does. A lowest-priority job ends the pass once everything due has run.
        /// </summary>
        static void RunLoopOnce()
        {
            // Not disposed: when the time cap ends the pass, the idle job is still queued and cancels later.
            var stop = new System.Threading.CancellationTokenSource();
            // Normally the idle job ends the pass; a steady stream of timer work (an animation)
            // can keep the dispatcher from ever going idle, so a pass is also capped in time.
            stop.CancelAfter(System.TimeSpan.FromMilliseconds(50));
            Dispatcher.UIThread.Post(() => stop.Cancel(), DispatcherPriority.SystemIdle);
            Dispatcher.UIThread.MainLoop(stop.Token);
        }

        static RawInputModifiers _buttons;

        public static void MouseMove(double x, double y)
        {
            Host.Window.MouseMove(new Point(x, y), _buttons);
            Dispatcher.UIThread.RunJobs();
        }

        /// <summary>button: 0 left, 1 middle, 2 right.</summary>
        public static void MouseDown(double x, double y, int button)
        {
            Host.Window.MouseDown(new Point(x, y), ToButton(button), _buttons);
            _buttons |= ToModifier(button);
            Dispatcher.UIThread.RunJobs();
        }

        public static void MouseUp(double x, double y, int button)
        {
            _buttons &= ~ToModifier(button);
            Host.Window.MouseUp(new Point(x, y), ToButton(button), _buttons);
            Dispatcher.UIThread.RunJobs();
        }

        /// <summary>deltaY &gt; 0 scrolls up (away from the user), as a wheel does.</summary>
        public static void Wheel(double x, double y, double deltaY)
        {
            Host.Window.MouseWheel(new Point(x, y), new Vector(0, deltaY), _buttons);
            Dispatcher.UIThread.RunJobs();
        }

        /// <summary>Presses and releases a key, named as Avalonia's Key enum ("Enter", "Tab", "A").</summary>
        public static void KeyStroke(string name, bool ctrl, bool shift)
        {
            var key = (Key)System.Enum.Parse(typeof(Key), name);
            System.Enum.TryParse<PhysicalKey>(name, out var physical);
            var modifiers = (ctrl ? RawInputModifiers.Control : RawInputModifiers.None) | (shift ? RawInputModifiers.Shift : RawInputModifiers.None);
            Host.Window.KeyPress(key, modifiers, physical, null);
            Dispatcher.UIThread.RunJobs();
            Host.Window.KeyRelease(key, modifiers, physical, null);
            Dispatcher.UIThread.RunJobs();
        }

        /// <summary>Text arriving as typed input (what a keyboard layout produces).</summary>
        public static void TypeText(string text)
        {
            Host.Window.KeyTextInput(text);
            Dispatcher.UIThread.RunJobs();
        }

        static MouseButton ToButton(int button) =>
            button == 2 ? MouseButton.Right : button == 1 ? MouseButton.Middle : MouseButton.Left;

        static RawInputModifiers ToModifier(int button) =>
            button == 2 ? RawInputModifiers.RightMouseButton : button == 1 ? RawInputModifiers.MiddleMouseButton : RawInputModifiers.LeftMouseButton;

        public static void ResizeWindow(int width, int height)
        {
            Host.Window.Width = width;
            Host.Window.Height = height;
            Pump(1);
        }

        public static void Capture(string path)
        {
            using var frame = Host.Window.CaptureRenderedFrame();
            frame?.Save(path);
        }

        static System.Net.Sockets.TcpListener _http;

        /// <summary>
        /// A minimal HTTP/1.0 file server on 127.0.0.1 for tests: GET /name serves root/name, anything
        /// else is a 404. Plain TCP, so it needs no URL reservation the way HttpListener does on Windows.
        /// </summary>
        public static int StartHttpServer(string root)
        {
            StopHttpServer();
            var dir = System.IO.Path.GetFullPath(root);
            var listener = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0);
            listener.Start();
            _http = listener;
            System.Threading.Tasks.Task.Run(async () =>
            {
                while (true)
                {
                    System.Net.Sockets.TcpClient client;
                    try { client = await listener.AcceptTcpClientAsync(); }
                    catch { return; } // stopped
                    _ = System.Threading.Tasks.Task.Run(() => Serve(client, dir));
                }
            });
            return ((System.Net.IPEndPoint)listener.LocalEndpoint).Port;
        }

        public static void StopHttpServer()
        {
            _http?.Stop();
            _http = null;
        }

        static void Serve(System.Net.Sockets.TcpClient client, string dir)
        {
            using (client)
            using (var stream = client.GetStream())
            {
                var reader = new System.IO.StreamReader(stream, System.Text.Encoding.ASCII, false, 1024, true);
                var request = reader.ReadLine() ?? "";
                while (!string.IsNullOrEmpty(reader.ReadLine())) { } // headers
                var parts = request.Split(' ');
                var name = parts.Length > 1 ? System.Uri.UnescapeDataString(parts[1].TrimStart('/')) : "";
                var path = System.IO.Path.GetFullPath(System.IO.Path.Combine(dir, name));
                byte[] body = path.StartsWith(dir) && System.IO.File.Exists(path) ? System.IO.File.ReadAllBytes(path) : null;
                var head = body != null
                    ? $"HTTP/1.0 200 OK\r\nContent-Length: {body.Length}\r\nConnection: close\r\n\r\n"
                    : "HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                var headBytes = System.Text.Encoding.ASCII.GetBytes(head);
                stream.Write(headBytes, 0, headBytes.Length);
                if (body != null) stream.Write(body, 0, body.Length);
            }
        }

        /// <summary>A w x h region of one freshly rendered frame as ARGB, row by row (0 outside the frame).</summary>
        public static int[] PixelsAt(int x, int y, int w, int h)
        {
            var result = new int[System.Math.Max(0, w) * System.Math.Max(0, h)];
            using var frame = Host.Window.CaptureRenderedFrame();
            if (frame == null) return result;
            using var buffer = frame.Lock();
            for (var row = 0; row < h; row++)
                for (var col = 0; col < w; col++)
                {
                    int px = x + col, py = y + row;
                    if (px < 0 || py < 0 || px >= buffer.Size.Width || py >= buffer.Size.Height) continue;
                    result[row * w + col] = ToArgb((uint)Marshal.ReadInt32(buffer.Address, py * buffer.RowBytes + px * 4), buffer.Format);
                }
            return result;
        }

        static int ToArgb(uint raw, PixelFormat format)
        {
            if (format == PixelFormat.Rgba8888)
            {
                // bytes R,G,B,A read little-endian as 0xAABBGGRR: swap red and blue into ARGB
                raw = (raw & 0xFF00FF00u) | ((raw & 0x00FF0000u) >> 16) | ((raw & 0x000000FFu) << 16);
            }
            return unchecked((int)raw);
        }

        /// <summary>The pixel at (x, y) of a freshly rendered frame, as ARGB (0 outside the frame).</summary>
        public static int PixelAt(int x, int y)
        {
            using var frame = Host.Window.CaptureRenderedFrame();
            if (frame == null) return 0;
            using var buffer = frame.Lock();
            if (x < 0 || y < 0 || x >= buffer.Size.Width || y >= buffer.Size.Height) return 0;
            var raw = (uint)Marshal.ReadInt32(buffer.Address, y * buffer.RowBytes + x * 4);
            if (buffer.Format == PixelFormat.Rgba8888)
            {
                // bytes R,G,B,A read little-endian as 0xAABBGGRR: swap red and blue into ARGB
                raw = (raw & 0xFF00FF00u) | ((raw & 0x00FF0000u) >> 16) | ((raw & 0x000000FFu) << 16);
            }
            return unchecked((int)raw);
        }
    }
}
#endif
