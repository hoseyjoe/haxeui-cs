using System.Threading.Tasks;
using Avalonia.Input.Platform;
using Avalonia.Threading;

namespace HaxeUICs
{
    /// <summary>
    /// The system clipboard's text, answered at once as Heaps' hxd.System answers it. Avalonia's
    /// clipboard is asynchronous, so each call waits for it in a nested dispatcher frame (as WPF's
    /// own Clipboard waits): the window keeps painting meanwhile, and a call gives up after
    /// TimeoutMs, when another program holds the clipboard open.
    /// </summary>
    public static class UIClipboard
    {
        const int TimeoutMs = 2000;

        static IClipboard Clipboard => Host.Window?.Clipboard;

        /// <summary>Puts text on the clipboard; false when there is no window yet or it failed.</summary>
        public static bool SetText(string text)
        {
            var clipboard = Clipboard;
            if (clipboard == null) return false;
            try
            {
                var ok = Wait(clipboard.SetTextAsync(text ?? ""));
                if (ok) _written = clipboard;
                return ok;
            }
            catch (System.Exception) { return false; }
        }

        /// <summary>The clipboard last written to, kept for Flush: a closed window has none.</summary>
        static IClipboard _written;

        /// <summary>The clipboard's text; null when it holds none, or it can't be read.</summary>
        public static string GetText()
        {
            var clipboard = Clipboard;
            if (clipboard == null) return null;
            try
            {
                var task = clipboard.TryGetTextAsync();
                return Wait(task) ? task.Result : null;
            }
            catch (System.Exception) { return null; }
        }

        /// <summary>Empties the clipboard of every format, not only text.</summary>
        public static bool Clear()
        {
            var clipboard = Clipboard;
            if (clipboard == null) return false;
            try { return Wait(clipboard.ClearAsync()); }
            catch (System.Exception) { return false; }
        }

        /// <summary>
        /// Hands what this program put on the clipboard to the OS, so it outlives the program
        /// (Windows' OleFlushClipboard); the host calls it on the way out.
        /// </summary>
        internal static void Flush()
        {
            var clipboard = _written;
            if (clipboard == null) return; // nothing of ours was ever on it
            _written = null;
            try { Wait(clipboard.FlushAsync()); }
            catch (System.Exception) { }
        }

        /// <summary>Runs the dispatcher until the task ends or TimeoutMs passes; whether it succeeded.</summary>
        static bool Wait(Task task)
        {
            if (!task.IsCompleted)
            {
                var frame = new DispatcherFrame();
                void stop() => Dispatcher.UIThread.Post(() => frame.Continue = false, DispatcherPriority.Send);
                task.ContinueWith(_ => stop(), TaskScheduler.Default);
                Task.Delay(TimeoutMs).ContinueWith(_ => stop(), TaskScheduler.Default);
                Dispatcher.UIThread.PushFrame(frame);
            }
            return task.IsCompletedSuccessfully;
        }
    }
}
