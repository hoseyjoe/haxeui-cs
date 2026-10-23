#if HAXEUI_CS_HEADLESS
using System.Runtime.InteropServices;
using Avalonia.Headless;
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
            using var stop = new System.Threading.CancellationTokenSource();
            Dispatcher.UIThread.Post(() => stop.Cancel(), DispatcherPriority.SystemIdle);
            Dispatcher.UIThread.MainLoop(stop.Token);
        }

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
