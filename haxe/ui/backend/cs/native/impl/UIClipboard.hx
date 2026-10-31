package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Action;
import cs.system.Action_1;
import cs.system.Environment;
import cs.system.Exception;
import cs.types.UInt8;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.backend.cs.net.Clipboard;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Threading;

/**
 * The system clipboard's text, answered at once as Heaps' hxd.System answers it. Avalonia's
 * clipboard is asynchronous, so each call waits for it in a nested dispatcher frame (as WPF's
 * own Clipboard waits): the window keeps painting meanwhile, and a call gives up after
 * TimeoutMs, when another program holds the clipboard open.
 */
@:native("HaxeUICs.UIClipboard")
@:nativeGen
class UIClipboard {
	static inline var TimeoutMs = 2000;
	static inline var RetryMs = 20;

	static function CurrentClipboard():IClipboard {
		var top = Host.TopLevel;
		return top != null ? top.Clipboard : null;
	}

	/**
	 * Windows' formats that keep a copy out of clipboard history (Win+V), the cloud clipboard
	 * and clipboard monitors, as KeePass sets them: the first by being there at all, the other
	 * two as a DWORD 0.
	 */
	public static final SensitiveFormats:Array<DataFormat_1<NativeArray<UInt8>>> = [
		DataFormat.CreateBytesPlatformFormat("ExcludeClipboardContentFromMonitorProcessing"),
		DataFormat.CreateBytesPlatformFormat("CanIncludeInClipboardHistory"),
		DataFormat.CreateBytesPlatformFormat("CanUploadToCloudClipboard")
	];

	/**
	 * Puts text on the clipboard; false when there is no window yet or it failed. Sensitive
	 * text (a password) goes on with SensitiveFormats beside it, on Windows: in one item, which
	 * Windows gets as one OLE data object offering every format.
	 */
	public static function SetText(text:String, sensitive:Bool):Bool {
		var clipboard = CurrentClipboard();
		if (clipboard == null) {
			return false;
		}
		try {
			var item = new DataTransferItem();
			item.SetText(text != null ? text : "");
			if (sensitive && RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
				for (format in SensitiveFormats) {
					item.Set(format, new NativeArray<UInt8>(4));
				}
			}
			var data = new DataTransfer();
			data.Add(item);
			var ok = Wait(clipboard.SetDataAsync(data));
			if (ok) {
				_written = clipboard;
			}
			return ok;
		} catch (e:Exception) {
			return false;
		}
	}

	/** The clipboard last written to, kept for Flush: a closed window has none. */
	static var _written:IClipboard;

	/**
	 * The clipboard's text; null when it holds none, or it can't be read. Text offered but not
	 * readable yet is asked for again until TimeoutMs: another program reading a copy (Windows'
	 * clipboard history does at once, for one marked sensitive) holds the clipboard open for
	 * some tens of milliseconds.
	 */
	public static function GetText():String {
		var clipboard = CurrentClipboard();
		if (clipboard == null) {
			return null;
		}
		try {
			var started = Environment.TickCount;
			while (true) {
				var task = ClipboardExtensions.TryGetTextAsync(clipboard);
				if (!Wait(task)) {
					return null;
				}
				if (task.Result != null) {
					return task.Result;
				}
				var formats = ClipboardExtensions.GetDataFormatsAsync(clipboard);
				if (!Wait(formats) || !OffersText(formats.Result)) {
					return null;
				}
				if (Environment.TickCount - started + RetryMs > TimeoutMs) {
					return null;
				}
				Wait(Task.Delay(RetryMs));
			}
		} catch (e:Exception) {
			return null;
		}
		return null;
	}

	static function OffersText(formats:IReadOnlyList<DataFormat>):Bool {
		var all:IReadOnlyCollection<DataFormat> = formats;
		for (i in 0...all.Count) {
			var format:DataFormat = formats[i];
			if (format.Equals(DataFormat.Text)) {
				return true;
			}
		}
		return false;
	}

	/** Empties the clipboard of every format, not only text. */
	public static function Clear():Bool {
		var clipboard = CurrentClipboard();
		if (clipboard == null) {
			return false;
		}
		try {
			return Wait(clipboard.ClearAsync());
		} catch (e:Exception) {
			return false;
		}
	}

	/**
	 * Hands what this program put on the clipboard to the OS, so it outlives the program
	 * (Windows' OleFlushClipboard); the host calls it on the way out.
	 */
	public static function Flush():Void {
		var clipboard = _written;
		if (clipboard == null) {
			return; // nothing of ours was ever on it
		}
		_written = null;
		try {
			Wait(clipboard.FlushAsync());
		} catch (e:Exception) {}
	}

	/** Runs the dispatcher until the task ends or TimeoutMs passes; whether it succeeded. */
	public static function Wait(task:Task):Bool {
		if (!task.IsCompleted) {
			var frame = new DispatcherFrame();
			var leave:Action = function() {
				frame.Continue = false;
			};
			var stop:Action_1<Task> = function(t:Task) {
				Dispatcher.UIThread.Post(leave, DispatcherPriority.Send);
			};
			task.ContinueWith(stop, TaskScheduler.Default);
			Task.Delay(TimeoutMs).ContinueWith(stop, TaskScheduler.Default);
			Dispatcher.UIThread.PushFrame(frame);
		}
		return task.Status == TaskStatus.RanToCompletion;
	}
}
