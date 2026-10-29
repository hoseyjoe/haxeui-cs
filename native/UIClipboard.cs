using System.Linq;
using System.Threading.Tasks;
using Avalonia.Input;
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
        const int RetryMs = 20;

        static IClipboard Clipboard => Host.Window?.Clipboard;

        /// <summary>
        /// Windows' formats that keep a copy out of clipboard history (Win+V), the cloud clipboard
        /// and clipboard monitors, as KeePass sets them: the first by being there at all, the other
        /// two as a DWORD 0.
        /// </summary>
        internal static readonly DataFormat<byte[]>[] SensitiveFormats =
        {
            DataFormat.CreateBytesPlatformFormat("ExcludeClipboardContentFromMonitorProcessing"),
            DataFormat.CreateBytesPlatformFormat("CanIncludeInClipboardHistory"),
            DataFormat.CreateBytesPlatformFormat("CanUploadToCloudClipboard"),
        };

        /// <summary>
        /// Puts text on the clipboard; false when there is no window yet or it failed. Sensitive
        /// text (a password) goes on with SensitiveFormats beside it, on Windows: in one item, which
        /// Windows gets as one OLE data object offering every format.
        /// </summary>
        public static bool SetText(string text, bool sensitive)
        {
            var clipboard = Clipboard;
            if (clipboard == null) return false;
            try
            {
                var item = new DataTransferItem();
                item.SetText(text ?? "");
                if (sensitive && System.OperatingSystem.IsWindows())
                    foreach (var format in SensitiveFormats)
                        item.Set(format, new byte[4]);
                var data = new DataTransfer();
                data.Add(item);
                var ok = Wait(clipboard.SetDataAsync(data));
                if (ok) _written = clipboard;
                return ok;
            }
            catch (System.Exception) { return false; }
        }

        /// <summary>The clipboard last written to, kept for Flush: a closed window has none.</summary>
        static IClipboard _written;

        /// <summary>
        /// The clipboard's text; null when it holds none, or it can't be read. Text offered but not
        /// readable yet is asked for again until TimeoutMs: another program reading a copy (Windows'
        /// clipboard history does at once, for one marked sensitive) holds the clipboard open for
        /// some tens of milliseconds.
        /// </summary>
        public static string GetText()
        {
            var clipboard = Clipboard;
            if (clipboard == null) return null;
            try
            {
                var deadline = System.Environment.TickCount64 + TimeoutMs;
                while (true)
                {
                    var task = clipboard.TryGetTextAsync();
                    if (!Wait(task)) return null;
                    if (task.Result != null) return task.Result;
                    var formats = clipboard.GetDataFormatsAsync();
                    if (!Wait(formats) || !formats.Result.Contains(DataFormat.Text)) return null;
                    if (System.Environment.TickCount64 + RetryMs > deadline) return null;
                    Wait(Task.Delay(RetryMs));
                }
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
        internal static bool Wait(Task task)
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
