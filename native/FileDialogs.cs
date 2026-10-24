using System.Collections.Generic;
using Avalonia.Controls;
using Avalonia.Platform.Storage;

namespace HaxeUICs
{
    /// <summary>What a file dialog tells the HaxeUI side when it closes.</summary>
    public interface IFileDialogListener
    {
        void OnFiles(string[] paths);
        void OnCancelled();
    }

    /// <summary>The OS open/save file pickers, through Avalonia's StorageProvider.</summary>
    public static class FileDialogs
    {
        /// <summary>
        /// Tests set this to answer every dialog at once without showing one: the paths chosen, or
        /// an empty array (or one with a null entry) for Cancel. Null shows the real dialog.
        /// </summary>
        public static string[] TestResponse;

        /// <param name="patterns">Glob patterns such as "*.lor"; empty for any file.</param>
        /// <param name="patternNames">A label for each pattern.</param>
        public static async void OpenFiles(string title, bool multiple, string[] patterns, string[] patternNames, IFileDialogListener listener)
        {
            try
            {
                if (TestResponse != null)
                {
                    Answer(TestResponse, listener);
                    return;
                }
                var storage = TopLevel.GetTopLevel(Host.Window)?.StorageProvider;
                if (storage == null || !storage.CanOpen)
                {
                    Cancel(listener);
                    return;
                }
                var files = await storage.OpenFilePickerAsync(new FilePickerOpenOptions
                {
                    Title = title,
                    AllowMultiple = multiple,
                    FileTypeFilter = Filters(patterns, patternNames),
                });
                var paths = new List<string>();
                foreach (var file in files)
                {
                    var path = file.TryGetLocalPath();
                    if (path != null) paths.Add(path);
                }
                Answer(paths.ToArray(), listener);
            }
            catch (System.Exception e)
            {
                Report(e);
                Cancel(listener);
            }
        }

        public static async void SaveFile(string title, string suggestedName, string[] patterns, string[] patternNames, IFileDialogListener listener)
        {
            try
            {
                if (TestResponse != null)
                {
                    Answer(TestResponse, listener);
                    return;
                }
                var storage = TopLevel.GetTopLevel(Host.Window)?.StorageProvider;
                if (storage == null || !storage.CanSave)
                {
                    Cancel(listener);
                    return;
                }
                var file = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
                {
                    Title = title,
                    SuggestedFileName = suggestedName,
                    FileTypeChoices = Filters(patterns, patternNames),
                });
                var path = file?.TryGetLocalPath();
                Answer(path != null ? new[] { path } : System.Array.Empty<string>(), listener);
            }
            catch (System.Exception e)
            {
                Report(e);
                Cancel(listener);
            }
        }

        /// <param name="defaultPath">The folder to start in, or null for the OS's choice.</param>
        public static async void OpenFolder(string title, bool multiple, string defaultPath, IFileDialogListener listener)
        {
            try
            {
                if (TestResponse != null)
                {
                    Answer(TestResponse, listener);
                    return;
                }
                var storage = TopLevel.GetTopLevel(Host.Window)?.StorageProvider;
                if (storage == null || !storage.CanPickFolder)
                {
                    Cancel(listener);
                    return;
                }
                var start = string.IsNullOrEmpty(defaultPath) ? null : await storage.TryGetFolderFromPathAsync(defaultPath);
                var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions
                {
                    Title = title,
                    AllowMultiple = multiple,
                    SuggestedStartLocation = start,
                });
                var paths = new List<string>();
                foreach (var folder in folders)
                {
                    var path = folder.TryGetLocalPath();
                    if (path != null) paths.Add(path);
                }
                Answer(paths.ToArray(), listener);
            }
            catch (System.Exception e)
            {
                Report(e);
                Cancel(listener);
            }
        }

        // These run from async void methods: anything thrown there would reach Avalonia's
        // dispatcher and end the app, so failures are reported instead, never thrown.
        static void Answer(string[] paths, IFileDialogListener listener)
        {
            if (paths.Length == 0 || System.Array.IndexOf(paths, null) >= 0)
            {
                Cancel(listener);
                return;
            }
            try { listener.OnFiles(paths); }
            catch (System.Exception e) { Report(e); }
        }

        static void Cancel(IFileDialogListener listener)
        {
            try { listener.OnCancelled(); }
            catch (System.Exception e) { Report(e); }
        }

        static void Report(System.Exception e)
        {
            System.Console.Error.WriteLine("haxeui-cs: a file dialog failed: " + e);
        }

        static List<FilePickerFileType> Filters(string[] patterns, string[] names)
        {
            if (patterns == null || patterns.Length == 0) return null;
            var filters = new List<FilePickerFileType>();
            for (var i = 0; i < patterns.Length; i++)
            {
                var name = names != null && i < names.Length && !string.IsNullOrEmpty(names[i]) ? names[i] : patterns[i];
                filters.Add(new FilePickerFileType(name) { Patterns = new[] { patterns[i] } });
            }
            return filters;
        }
    }
}
