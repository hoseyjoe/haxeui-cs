using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace DriveWindowApp
{
    /// <summary>
    /// What the check needs from Windows, all read only: who owns the foreground window, and which
    /// extended window styles our own window has; and (StartWatch) whether any visible window of this
    /// process is ever on a display.
    /// </summary>
    public static class Win32Probe
    {
        /// <summary>1: the foreground window belongs to this process. 0: to another. -1: there is none (or this is not Windows).</summary>
        public static int ForegroundIsOurs()
        {
            if (!OperatingSystem.IsWindows()) return -1;
            var foreground = GetForegroundWindow();
            if (foreground == IntPtr.Zero) return -1;
            GetWindowThreadProcessId(foreground, out var pid);
            return pid == (uint)Environment.ProcessId ? 1 : 0;
        }

        /// <summary>
        /// GWL_EXSTYLE of this process's top-level window of that title; -1 if there is none (or this is
        /// not Windows). Only this process's windows are asked.
        /// </summary>
        public static int ExStyleOfOurWindow(string title)
        {
            if (!OperatingSystem.IsWindows()) return -1;
            int found = -1;
            EnumWindows((window, _) =>
            {
                GetWindowThreadProcessId(window, out var pid);
                if (pid != (uint)Environment.ProcessId) return true;
                var text = new StringBuilder(256);
                GetWindowTextW(window, text, text.Capacity);
                if (text.ToString() != title) return true;
                found = (int)GetWindowLongPtrW(window, -20).ToInt64(); // GWL_EXSTYLE
                return false;
            }, IntPtr.Zero);
            return found;
        }

        /// <summary>
        /// How many visible top-level windows this process has (a file picker would be one more); -1
        /// if this is not Windows.
        /// </summary>
        public static int VisibleWindowCount()
        {
            if (!OperatingSystem.IsWindows()) return -1;
            int count = 0;
            EnumWindows((window, _) =>
            {
                GetWindowThreadProcessId(window, out var pid);
                if (pid == (uint)Environment.ProcessId && IsWindowVisible(window)) count++;
                return true;
            }, IntPtr.Zero);
            return count;
        }

        // ---- the watch: was a visible window of ours ever on a display? ----

        static volatile bool watching;
        static volatile string seen = "";
        static long polls;
        static Thread watcher;

        /// <summary>
        /// Starts a background thread, as early as the caller likes (before the window exists), that polls
        /// as fast as it can (a yield between polls, so about every millisecond or better) every top-level
        /// window of this process: a visible one whose rectangle overlaps any monitor is recorded (the
        /// first only) as "(l,t)-(r,b)". Read only: EnumWindows, IsWindowVisible, GetWindowRect,
        /// EnumDisplayMonitors. The monitors are asked afresh each poll, so they are in the same
        /// coordinates as the window rectangle whatever the process's DPI awareness is at that moment.
        /// </summary>
        public static void StartWatch()
        {
            if (!OperatingSystem.IsWindows() || watcher != null) return;
            watching = true;
            watcher = new Thread(() =>
            {
                while (watching)
                {
                    try { if (Poll()) Interlocked.Increment(ref polls); } catch { }
                    Thread.Yield();
                }
            });
            watcher.IsBackground = true;
            watcher.Name = "Win32Probe.watch";
            watcher.Start();
        }

        /// <summary>The position of the first visible window of ours seen on a display so far, "(l,t)-(r,b)"; "" if none yet (or no watch).</summary>
        public static string SeenOnADisplay()
        {
            return seen;
        }

        /// <summary>How many polls have completed with every step working, so a watch that always fails cannot look like one that saw nothing.</summary>
        public static int PollCount()
        {
            return (int)System.Math.Min(int.MaxValue, Interlocked.Read(ref polls));
        }

        /// <summary>Stops the watch (its thread ends).</summary>
        public static void StopWatch()
        {
            watching = false;
        }

        /// <summary>One poll; true if every step of it worked.</summary>
        static bool Poll()
        {
            var ours = (uint)Environment.ProcessId;
            bool ok = true;
            bool enumerated = EnumWindows((window, _) =>
            {
                try
                {
                    GetWindowThreadProcessId(window, out var pid);
                    if (pid != ours || !IsWindowVisible(window)) return true;
                    if (!GetWindowRect(window, out var rect)) return true;
                    if (rect.Right <= rect.Left || rect.Bottom <= rect.Top) return true;
                    bool onADisplay = false;
                    if (!EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (monitor, dc, area, data) =>
                    {
                        var m = Marshal.PtrToStructure<RECT>(area);
                        if (rect.Left < m.Right && rect.Right > m.Left && rect.Top < m.Bottom && rect.Bottom > m.Top) onADisplay = true;
                        return true;
                    }, IntPtr.Zero)) ok = false;
                    if (onADisplay && seen == "") seen = "(" + rect.Left + "," + rect.Top + ")-(" + rect.Right + "," + rect.Bottom + ")";
                }
                catch
                {
                    ok = false;
                }
                return true;
            }, IntPtr.Zero);
            return enumerated && ok;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct RECT
        {
            public int Left, Top, Right, Bottom;
        }

        delegate bool MonitorEnumProc(IntPtr monitor, IntPtr dc, IntPtr area, IntPtr data);

        [DllImport("user32.dll")]
        static extern bool GetWindowRect(IntPtr window, out RECT rect);

        [DllImport("user32.dll")]
        static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc callback, IntPtr data);

        delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

        [DllImport("user32.dll")]
        static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern int GetWindowTextW(IntPtr window, StringBuilder text, int count);

        [DllImport("user32.dll")]
        static extern bool IsWindowVisible(IntPtr window);

        [DllImport("user32.dll")]
        static extern IntPtr GetWindowLongPtrW(IntPtr window, int index);

        [DllImport("user32.dll")]
        static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    }
}
