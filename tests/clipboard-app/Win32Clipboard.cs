using System;
using System.Runtime.InteropServices;

namespace ClipboardApp
{
    /// <summary>
    /// What Windows' clipboard itself holds, read through Win32 rather than Avalonia, as another
    /// program (clipboard history) reads it.
    /// </summary>
    public static class Win32Clipboard
    {
        /// <summary>
        /// The bytes the clipboard holds in the registered format of that name, as lowercase hex;
        /// null when it holds nothing in that format, it can't be opened, or this is not Windows.
        /// </summary>
        public static string Format(string name)
        {
            if (!OperatingSystem.IsWindows()) return null;
            var id = RegisterClipboardFormatW(name);
            if (id == 0 || !IsClipboardFormatAvailable(id)) return null;
            if (!OpenClipboard(IntPtr.Zero)) return null;
            try
            {
                var handle = GetClipboardData(id); // ours is rendered late: Windows asks the data object now
                if (handle == IntPtr.Zero) return null;
                var data = GlobalLock(handle);
                if (data == IntPtr.Zero) return null;
                try
                {
                    var bytes = new byte[(int)GlobalSize(handle)];
                    Marshal.Copy(data, bytes, 0, bytes.Length);
                    return Convert.ToHexStringLower(bytes);
                }
                finally { GlobalUnlock(handle); }
            }
            finally { CloseClipboard(); }
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern uint RegisterClipboardFormatW(string name);

        [DllImport("user32.dll")]
        static extern bool IsClipboardFormatAvailable(uint format);

        [DllImport("user32.dll")]
        static extern bool OpenClipboard(IntPtr owner);

        [DllImport("user32.dll")]
        static extern bool CloseClipboard();

        [DllImport("user32.dll")]
        static extern IntPtr GetClipboardData(uint format);

        [DllImport("kernel32.dll")]
        static extern IntPtr GlobalLock(IntPtr handle);

        [DllImport("kernel32.dll")]
        static extern bool GlobalUnlock(IntPtr handle);

        [DllImport("kernel32.dll")]
        static extern UIntPtr GlobalSize(IntPtr handle);
    }
}
