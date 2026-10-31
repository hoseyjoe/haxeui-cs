package haxe.ui.backend.cs.native.impl;

#if haxeui_cs_headless
import cs.NativeArray;
import cs.system.Action;
import cs.system.Enum;
import cs.system.TimeSpan;
import cs.system.Uri;
import cs.system.io.File;
import cs.system.io.Path;
import cs.system.io.StreamReader;
import cs.system.net.IPAddress;
import cs.system.net.IPEndPoint;
import cs.system.net.sockets.TcpClient;
import cs.system.net.sockets.TcpListener;
import cs.system.text.Encoding;
import cs.system.threading.CancellationTokenSource;
import cs.system.threading.Thread;
import cs.system.threading.ThreadStart;
import haxe.ui.backend.cs.native.impl.Host.Host;
import haxe.ui.backend.cs.net.App;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Clipboard;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Threading;

/**
 * Drives the headless host for tests: runs queued work and render ticks, injects input and
 * captures frames. Haxe reaches it through haxe.ui.backend.cs.TestDriver.
 */
@:native("HaxeUICs.HeadlessDriver")
class HeadlessDriver {
	public static function Pump(frames:Int):Void {
		for (i in 0...frames) {
			RunLoopOnce();
			Host.RunFrame(); // one HaxeUI frame (callLater batch) per pump, whatever the wall clock did
			AvaloniaHeadlessPlatform.ForceRenderTimerTick(1);
			Dispatcher.UIThread.RunJobs(null);
		}
	}

	/**
	 * One pass of the real dispatcher loop: RunJobs alone never promotes due DispatcherTimers,
	 * the main loop does. A lowest-priority job ends the pass once everything due has run.
	 */
	static function RunLoopOnce():Void {
		// Not disposed: when the time cap ends the pass, the idle job is still queued and cancels later.
		var stop = new CancellationTokenSource();
		// Normally the idle job ends the pass; a steady stream of timer work (an animation)
		// can keep the dispatcher from ever going idle, so a pass is also capped in time.
		stop.CancelAfter(TimeSpan.FromMilliseconds(50));
		var idle:Action = function() {
			stop.Cancel();
		};
		Dispatcher.UIThread.Post(idle, DispatcherPriority.SystemIdle);
		Dispatcher.UIThread.MainLoop(stop.Token);
	}

	// RawInputModifiers' flags of the buttons held.
	static var _buttons:Int = 0;

	static function Held():RawInputModifiers {
		return cast _buttons;
	}

	public static function MouseMove(x:Float, y:Float):Void {
		HeadlessWindowExtensions.MouseMove(Host.Window, new Point(x, y), Held());
		Dispatcher.UIThread.RunJobs(null);
	}

	/** button: 0 left, 1 middle, 2 right. */
	public static function MouseDown(x:Float, y:Float, button:Int):Void {
		HeadlessWindowExtensions.MouseDown(Host.Window, new Point(x, y), ToButton(button), Held());
		_buttons |= ToModifier(button);
		Dispatcher.UIThread.RunJobs(null);
	}

	public static function MouseUp(x:Float, y:Float, button:Int):Void {
		_buttons &= ~ToModifier(button);
		HeadlessWindowExtensions.MouseUp(Host.Window, new Point(x, y), ToButton(button), Held());
		Dispatcher.UIThread.RunJobs(null);
	}

	/** deltaY > 0 scrolls up (away from the user), as a wheel does. */
	public static function Wheel(x:Float, y:Float, deltaY:Float, deltaX:Float):Void {
		HeadlessWindowExtensions.MouseWheel(Host.Window, new Point(x, y), new Vector(deltaX, deltaY), Held());
		Dispatcher.UIThread.RunJobs(null);
	}

	/** Presses and releases a key, named as Avalonia's Key enum ("Enter", "Tab", "A"). */
	public static function KeyStroke(name:String, ctrl:Bool, shift:Bool):Void {
		var key:Key = cast Enum.Parse(cs.Lib.toNativeType(cast Key), name);
		var physical = PhysicalKey.None;
		try {
			physical = cast Enum.Parse(cs.Lib.toNativeType(cast PhysicalKey), name);
		} catch (e:Dynamic) {} // a key with no physical key of that name
		var bits = (ctrl ? (cast RawInputModifiers.Control : Int) : 0) | (shift ? (cast RawInputModifiers.Shift : Int) : 0);
		var modifiers:RawInputModifiers = cast bits;
		HeadlessWindowExtensions.KeyPress(Host.Window, key, modifiers, physical, null);
		Dispatcher.UIThread.RunJobs(null);
		HeadlessWindowExtensions.KeyRelease(Host.Window, key, modifiers, physical, null);
		Dispatcher.UIThread.RunJobs(null);
	}

	/** Text arriving as typed input (what a keyboard layout produces). */
	public static function TypeText(text:String):Void {
		HeadlessWindowExtensions.KeyTextInput(Host.Window, text);
		Dispatcher.UIThread.RunJobs(null);
	}

	static function ToButton(button:Int):MouseButton {
		return button == 2 ? MouseButton.Right : button == 1 ? MouseButton.Middle : MouseButton.Left;
	}

	static function ToModifier(button:Int):Int {
		return button == 2 ? (cast RawInputModifiers.RightMouseButton : Int) : button == 1 ? (cast RawInputModifiers.MiddleMouseButton : Int) : (cast RawInputModifiers.LeftMouseButton : Int);
	}

	public static function ResizeWindow(width:Int, height:Int):Void {
		Host.Window.Width = width;
		Host.Window.Height = height;
		Pump(1);
	}

	public static function Capture(path:String):Void {
		var frame = HeadlessWindowExtensions.CaptureRenderedFrame(Host.Window);
		if (frame != null) {
			Scope.run(frame, () -> frame.Save(path, null));
		}
	}

	static var _http:TcpListener;

	/** How many connections the HTTP server has taken since it started. */
	public static var HttpHits(default, null):Int = 0;

	/**
	 * A minimal HTTP/1.0 file server on 127.0.0.1 for tests: GET /name serves root/name, anything
	 * else is a 404. Plain TCP, so it needs no URL reservation the way HttpListener does on Windows.
	 */
	public static function StartHttpServer(root:String, delayMs:Int):Int {
		StopHttpServer();
		HttpHits = 0;
		var dir = Path.GetFullPath(root);
		var listener = new TcpListener(IPAddress.Loopback, 0);
		listener.Start();
		_http = listener;
		// Background threads, so a server nobody stopped doesn't hold the process.
		var accept:ThreadStart = function() {
			while (true) {
				var client:TcpClient;
				try {
					client = listener.AcceptTcpClient();
				} catch (e:Dynamic) {
					return; // stopped
				}
				HttpHits++;
				var serve:ThreadStart = function() {
					if (delayMs > 0) {
						Thread.Sleep(delayMs);
					}
					Serve(client, dir);
				};
				var thread = new Thread(serve);
				thread.IsBackground = true;
				thread.Start();
			}
		};
		var thread = new Thread(accept);
		thread.IsBackground = true;
		thread.Start();
		return (cast listener.LocalEndpoint : IPEndPoint).Port;
	}

	public static function StopHttpServer():Void {
		if (_http != null) {
			_http.Stop();
		}
		_http = null;
	}

	// On a thread of its own, where anything thrown would end the process: a client that goes away
	// mid-request just ends its request.
	static function Serve(client:TcpClient, dir:String):Void {
		try {
			var stream = client.GetStream();
			var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true);
			var request = reader.ReadLine();
			if (request == null) {
				request = "";
			}
			var header = reader.ReadLine();
			while (header != null && header != "") { // headers
				header = reader.ReadLine();
			}
			var parts = request.split(" ");
			var name = parts.length > 1 ? Uri.UnescapeDataString(parts[1]) : "";
			while (StringTools.startsWith(name, "/")) {
				name = name.substr(1);
			}
			var path = Path.GetFullPath(Path.Combine(dir, name));
			var body:NativeArray<cs.types.UInt8> = StringTools.startsWith(path, dir) && File.Exists(path) ? File.ReadAllBytes(path) : null;
			var head = body != null ? "HTTP/1.0 200 OK\r\nContent-Length: " + body.Length + "\r\nConnection: close\r\n\r\n" : "HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
			var headBytes = Encoding.ASCII.GetBytes(head);
			stream.Write(headBytes, 0, headBytes.Length);
			if (body != null) {
				stream.Write(body, 0, body.Length);
			}
			stream.Close();
		} catch (e:Dynamic) {}
		client.Close();
	}

	/** A w x h region of one freshly rendered frame as ARGB, row by row (0 outside the frame). */
	public static function PixelsAt(x:Int, y:Int, w:Int, h:Int):NativeArray<Int> {
		var result = new NativeArray<Int>((w > 0 ? w : 0) * (h > 0 ? h : 0));
		var frame = HeadlessWindowExtensions.CaptureRenderedFrame(Host.Window);
		if (frame == null) {
			return result;
		}
		Scope.run(frame, () -> {
			var buffer = frame.Lock();
			Scope.run(buffer, () -> {
				for (row in 0...h) {
					for (col in 0...w) {
						var px = x + col, py = y + row;
						if (px < 0 || py < 0 || px >= buffer.Size.Width || py >= buffer.Size.Height) {
							continue;
						}
						result[row * w + col] = ToArgb(Marshal.ReadInt32(buffer.Address, py * buffer.RowBytes + px * 4), buffer.Format);
					}
				}
			});
		});
		return result;
	}

	static function ToArgb(raw:Int, format:PixelFormat):Int {
		if (format.Equals(PixelFormat.Rgba8888)) {
			// bytes R,G,B,A read little-endian as 0xAABBGGRR: swap red and blue into ARGB
			return (raw & 0xFF00FF00) | ((raw & 0x00FF0000) >>> 16) | ((raw & 0x000000FF) << 16);
		}
		return raw;
	}

	/**
	 * What the clipboard holds in the platform format of that name, as lowercase hex; null
	 * when it holds nothing in that format.
	 */
	public static function ClipboardFormat(name:String):String {
		var task = ClipboardExtensions.TryGetValueAsync(Host.Window.Clipboard, DataFormat.CreateBytesPlatformFormat(name));
		if (!UIClipboard.Wait(task) || task.Result == null) {
			return null;
		}
		var bytes = task.Result;
		var hex = new StringBuf();
		for (i in 0...bytes.Length) {
			var b:Int = bytes[i];
			hex.add(StringTools.hex(b, 2).toLowerCase());
		}
		return hex.toString();
	}

	/** The pixel at (x, y) of a freshly rendered frame, as ARGB (0 outside the frame). */
	public static function PixelAt(x:Int, y:Int):Int {
		return PixelsAt(x, y, 1, 1)[0];
	}
}
#end
