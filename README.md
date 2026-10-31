# haxeui-cs

A [HaxeUI](https://haxeui.org) backend for Haxe's C# target. A HaxeUI app compiles to C#, and the
generated code builds and runs as an ordinary .NET 10 desktop program that draws through
[Avalonia](https://avaloniaui.net). It is a *composite* backend: each HaxeUI component is a plain
Avalonia panel, and HaxeUI does all the layout, styling and theming itself, as it does on html5 and
heaps.

It is built on **haxeui-core-joe** (`haxelib dev haxeui-core …/haxeui-core-joe`), not upstream
haxeui-core. Its first real app is JoeClash's story editor, Joeditor (`tools.joeditor.cs.hxml`).

## Requirements

- Haxe **4.3.x** (Haxe 5 drops the C# target)
- .NET **10** SDK (`dotnet` on the PATH). Avalonia 12.1.4 arrives through NuGet on first build.
- haxelibs: `haxeui-core` (haxeui-core-joe), `haxeui-cs` (this repo: `haxelib dev haxeui-cs <path to your clone>`)

## Building an app

```hxml
-cp src
-main Main
-lib haxeui-core
-lib haxeui-cs
-cs bin/cs
```

`haxe app.hxml` writes C# to `bin/cs/src`, writes `bin/cs/Main.csproj`, and runs `dotnet build`.
The program is `bin/cs/bin/Debug/net10.0/Main.dll` (run it with `dotnet`, or the `.exe` beside it).

```haxe
var app = new HaxeUIApp({width: 1280, height: 860, title: "My app"}); // all optional
app.ready(function() {
    app.addComponent(new MainView());
    app.start();
});
```

On the desktop, `ready()` runs Avalonia's loop and returns only when the window closes; closing the
window ends the process.

The options also take `resizable` (default true), `minWidth`, `minHeight` and `maximized`.
`app.icon = "icon.png"` sets the window's icon (a Haxe resource or an image file), and
`app.exit()` closes the window, which ends the app as the user closing it does.

A NuGet package the app's own code needs goes into the generated `.csproj` with
`--macro haxe.ui.backend.cs.macros.Build.addPackage("Microsoft.Data.Sqlite", "10.0.0")`, and the
app's own C# files (a `.cs` file, or a folder of them) with
`--macro haxe.ui.backend.cs.macros.Build.addNative("src-cs/native")`, for externs to call.

| Define | Effect |
|---|---|
| `-D haxeui_cs_run` | run the program straight after building it |
| `-D haxeui_cs_headless` | headless Avalonia (real Skia drawing, no OS window) plus `haxe.ui.backend.cs.TestDriver`, for tests |
| `-D haxeui_cs_no_dotnet` | stop after writing the `.csproj` |
| `-D haxeui_cs_publish=<rid>` | publish a release build as one self-contained file instead (see Publishing) |
| `-D haxeui_cs_trim` | with `haxeui_cs_publish`: trim the libraries that allow it, not the app's own (see Publishing) |
| `-D haxeui_cs_compress` | with `haxeui_cs_publish`: compress the file, smaller and slower to start (see Publishing) |
| `-D haxeui_cs_android` | an Android app instead (see Android) |
| `-debug` | console `Exe` instead of `WinExe` (headless builds are always `Exe`) |

hxc's `-D dotnet` writes the `.dll` itself, so none of the project steps run: no `.csproj`, no
`dotnet build`, and `addPackage` and `addNative` do nothing. `haxeui_cs_run`, `haxeui_cs_publish` and
`haxeui_cs_android` are refused. `native/*.cs` has to be built first into an assembly (with
`HAXEUI_CS_HEADLESS` defined for a headless app) and given to hxc with `--net-lib`, with
`Avalonia.Base.dll` and `Avalonia.Controls.dll` and `-D unsafe`, and it and its dependencies copied
beside the program's `.dll` to run it.

`haxe.ui.backend.cs.WindowCapture.save(path)` photographs the window, desktop or headless.
`haxe.ui.backend.cs.WindowBackground.set(0xRRGGBB)` sets what shows behind the components (white
until then); a dark theme sets its own, as an html5 app sets the page's background.
`haxe.ui.backend.cs.SvgPalette.set([0x555B66 => 0xFFFFFF])` recolours every SVG image, on screen and
from then on, as heaps-svg's `SvgIcons.setPalette` does for a dark theme's icons (`null`: as authored).

`haxe.ui.backend.cs.WindowClose.onRequest` is asked when the user closes the window (its close
button, Alt+F4), as a Heaps app's `hxd.Window.onClose` is: return false to keep it open, offer
unsaved work for saving, then call `app.exit()`, which never asks it. One that throws is reported
and the window closes.

`haxe.ui.backend.cs.BackButton.addListener(fn)` hears Android's back (gesture or button), newest
listener first: a listener that returns true has taken it (closing a dialog, going up a level), and
when none does the app goes to the background. `removeListener` and `clearListeners` undo that.
`haxe.ui.backend.cs.AppLifecycle.onPause` runs when the app goes to the background, where Android
may end it without a word: the place to save. The desktop never calls either.

`haxe.ui.backend.cs.Clipboard` has `setText`, `getText` and `clear` (every format, not just text),
answered at once as Heaps' `hxd.System.setClipboardText` is: each waits for the OS in a nested
dispatcher frame, so the window keeps painting, and gives up after two seconds if another program
holds the clipboard. What the app copied is handed to the OS on the way out (`OleFlushClipboard`), so
it stays on the clipboard after the app ends, as in any program. `setText(text, true)` copies a
password: on Windows the text goes on with `ExcludeClipboardContentFromMonitorProcessing`,
`CanIncludeInClipboardHistory` and `CanUploadToCloudClipboard` (a DWORD 0) beside it, as KeePass's
does, so it stays out of clipboard history (Win+V), the cloud clipboard and clipboard monitors, and
a later `clear` leaves nothing of it behind. Other systems get plain text.

### Publishing

`-D haxeui_cs_publish=<rid>` publishes a release build for one runtime instead of the debug
build: a single self-contained file, with the .NET runtime and the native libraries (Skia,
HarfBuzz) inside and no `.pdb`, in `<cs-out>/publish/<rid>/`. The machine it runs on needs
nothing installed. Runtime ids are .NET's: `win-x64`, `win-arm64`, `linux-x64`, `osx-arm64`,
`osx-x64`.

```
haxe app.hxml -D haxeui_cs_publish=win-x64
```

With `-D haxeui_cs_run` the published program runs too, when it was published for this OS. It is
the `dotnet publish` of the generated `.csproj` with `--self-contained`,
`-p:PublishSingleFile=true`, `-p:IncludeNativeLibrariesForSelfExtract=true` and
`-p:DebugType=none`, so it can also be run by hand with other settings.

- It is about 100 MB, most of it the .NET libraries. `-D haxeui_cs_trim` trims those to what is
  used (`PublishTrimmed`, `TrimMode=partial`), and `-D haxeui_cs_compress` compresses the file
  (`EnableCompressionInSingleFile`). For one app on win-x64:

  | | File | Window shows |
  |---|---|---|
  | neither | 102 MB | 1.4 s |
  | `haxeui_cs_compress` | 48 MB | 2.2 s |
  | `haxeui_cs_trim` | 44 MB | |
  | both | 23 MB | 1.6 s |

  An installer or zip compresses the untrimmed file to 32-43 MB without the slower start.
- Trimming is only partial: just the assemblies that declare themselves trimmable (.NET's own,
  Avalonia's) lose what nothing calls. Haxe's output and HaxeUI find classes by name at run time,
  so the app's own assembly, which does not, is kept whole. The trimmer's warnings while
  publishing (IL2070, IL2075...) are Haxe's dynamic field access (`haxe.lang.Runtime`), which it
  cannot follow: a `Dynamic` reaching a .NET or Avalonia member by name could find it trimmed away,
  so try a trimmed build's native paths (files, clipboard, network) before shipping it. The test
  suite passes trimmed: `haxe tests/headless.hxml -D haxeui_cs_publish=win-x64 -D haxeui_cs_trim`.
- `Sys.programPath()` is an empty string in a single-file program (Haxe's own `Sys`; .NET warns
  about it while publishing). For the program's own folder use
  `cs.Syntax.code("System.AppContext.BaseDirectory")`. Relative paths are still relative to the
  folder it was started from.
- The native libraries are unpacked to a temporary folder the first time it runs.
- For a Mac it is a plain program, not a signed `.app` bundle. On Linux a real window needs the
  libraries in the Linux section below.

### Android

`-D haxeui_cs_android` builds an Android app from the same program: a debug APK, from
`templates/AndroidApp.csproj` and `templates/android/MainActivity.cs`. With `-D haxeui_cs_run` it is
installed on the device adb sees (`ANDROID_SERIAL` picks one) and launched. It needs .NET's
`android` workload (`dotnet workload install android`), the Android SDK it brings, and adb.

```
haxe app.hxml -D haxeui_cs_android -D haxeui_cs_android_id=com.example.app -D haxeui_cs_android_label="My app" -D haxeui_cs_run
```

| Define | Effect |
|---|---|
| `-D haxeui_cs_android_id=<id>` | the application id (required) |
| `-D haxeui_cs_android_label=<label>` | the name under the launcher icon (required) |
| `-D haxeui_cs_android_abi=<abi>` | `arm64-v8a`, a phone (the default), or `x86_64`, the emulator |

- `main` runs from `MainActivity` once per process, with the app's private files folder as the
  working directory, so a relative path (a state file) lands there. `ready()` returns at once; its
  callback runs when the screen has a size. Rotating resizes the app (RESIZE), it never restarts it.
- The app fills the screen with the system bars hidden; a swipe from an edge shows them for a while.
- Back goes to `BackButton`'s listeners, else sends the app to the background. Save in
  `AppLifecycle.onPause`: Android ends background apps when it needs the memory.
- `Dialogs.openFile` shows the system picker. The file chosen is copied into `files/picked/` (the
  same file picked again is the same copy) and that path is the answer; any failure, including a
  copy that comes up short, is said in a message box. A name too long for the phone's file system
  is cut to fit. One file at a time; extensions do not filter it. Folder and save dialogs cancel.
- A finger has no hover, so tooltips come by long press, and letting go is not a click.
- `haxe.ui.backend.cs.Density.scaleFor(designWidth)` is the `Toolkit.scale` that gives `designWidth`
  units across the short edge in whole device pixels per unit, the same physical size as
  heaps-android. Set it before the first component.
- Not yet: publishing (`haxeui_cs_publish`), so neither its trimming nor its compression.

## Testing

`haxe tests/headless.hxml` builds and runs the backend's own suite headlessly (add
`-D test=<Case>` for one case, `-D UTEST_PATTERN=<test>` for one test). `TestDriver` pumps the
dispatcher, injects clicks, wheel, keys and typing at window coordinates, and reads back rendered
pixels. `haxe tests/exit-app/build.hxml` is the desktop check: a real window, a repeating
`haxe.Timer`, and the process must exit by itself when the window closes.
`haxe tests/early-add/build.hxml` checks that a component added before the window exists (as
HaxeUIApp's preloader is) appears once it does. `haxe tests/window-app/build.hxml` opens a window
with every window option, checks an idle app stays idle, and ends itself with `app.exit()`.
`haxe tests/clipboard-app/build.hxml` checks the OS clipboard (headless, Avalonia's is in memory) and
`WindowClose` in a real window; the text it prints last must still be on the clipboard after it ends
(`Get-Clipboard` on Windows). On Windows it reads a sensitive copy's formats back through Win32 and,
with `history.ps1`, checks that clipboard history took a plain copy but not the sensitive one (with
history off it says so and skips that).

`bash tests/android-app/check-device.sh` (with `ANDROID_SERIAL` set) builds, installs and drives a
small Android app on a device and reads what it reports from logcat: a tap is a click, rotation,
back with and without a listener, a kill and relaunch, full screen, a long-press tooltip, the system
picker (it pushes a file to Downloads and picks it through the picker's own screens) and the
keyboard. It uninstalls the app first and puts the rotation settings back.

### Linux

The build output is plain `net10.0`, so a program built on Windows runs on Linux as it is:
`dotnet <app>.dll` with a .NET 10 runtime. Verified under WSL2 Ubuntu 24.04 with WSLg: the whole
headless suite, and exit-app, early-add and window-app in a real window. A real window needs
Avalonia's X11 libraries; a minimal Ubuntu lacks two of them, `sudo apt install libice6 libsm6`
(or unpack those two packages anywhere and put their `lib` folder on `LD_LIBRARY_PATH`).

The parity gallery (`tools/gallery`) puts every component class core has, data-filled samples and
style samples on pages of 24. It builds them for haxeui-cs and for haxeui-html5, the reference,
and sets each cs page above its html5 twin in `tools/gallery/out/compare/`:

```
haxe tools/gallery/gallery.cs.hxml
dotnet tools/gallery/bin/bin/Debug/net10.0/Gallery.dll   # and again with --dark
haxe tools/gallery/gallery.html5.hxml
python -I tools/gallery/compare.py                      # needs Pillow and Microsoft Edge
```

## How it fits together

- `native/*.cs` (namespace `HaxeUICs`) is everything Avalonia: the host and its window, `UIPanel`
  (one per component) and the `UIPainter` that paints its style and canvas drawing, text
  (`UIText`), text input (`UITextInput`, a chrome-less TextBox), images, input routing, file
  dialogs and the headless driver. It knows nothing of HaxeUI.
- `haxe/ui/backend/*Impl.hx` are the 20 files haxeui-core expects, on externs to those classes
  (`haxe/ui/backend/cs/native/Native.hx`).
- `haxe/ui/backend/cs/macros/Build.hx` turns Haxe's C# output into a .NET build
  (`templates/App.csproj`).

## Behaviour worth knowing

- The generated `Main` is marked `[STAThread]`, as every Avalonia app's is: Windows' OLE (the
  clipboard, drag and drop) works only on a single-threaded apartment, and Haxe's entry point
  leaves the main thread multi-threaded. Under hxc's `-D dotnet`, `main` is marked instead, and hxc
  carries that to the entry point it writes.
- `callLater` runs with the next frame (about 60 a second), as html5's `requestAnimationFrame`.
  Haxe's own event loop (`haxe.Timer`, `haxe.MainLoop`) runs when it next needs to and straight
  after any frame, input or timer; an idle app is woken about four times a second, not a hundred.
- Canvas drawing follows haxeui-heaps (h2d.Graphics): `fillStyle(c)` begins a fill and
  `fillStyle(null)` ends it, and the path drawn in between is filled even without `beginPath`.
  Each `moveTo` starts a new polygon, filled on its own and then outlined, in drawing order: a
  later shape covers an earlier outline, and overlapping polygons of one fill cut no holes.
- **`componentGraphics.layers`** (`haxe.ui.backend.cs.Layers`) is a haxeui-cs addition for
  content that moves every frame while its pixels mostly don't, as an app on heaps drops to h2d:
  groups with a matrix, an opacity (a group fades as one image) and an optional mask, holding RGBA
  bitmaps placed in their group's units, drawn above the canvas drawing. Moving a group is a
  repaint, not a raster. A bitmap may have more pixels than units (`layers.deviceScale`), so it
  stays sharp at 150%, where `setPixels` is one pixel per unit, as html5's canvas is. They are drawn
  straight through Skia: Avalonia's own opacity mask misplaces an image brush under a render
  scaling, and its `PushOpacity` fades each drawing on its own.
- `StringTools.startsWith` and `endsWith` compare code unit by code unit, as on every other
  target. Haxe's C# std leaves them to .NET's culture rules, where a BOM or soft hyphen matches
  anything; haxeui-cs corrects that at compile time.
- `haxe.zip.Uncompress` works (Haxe's C# std throws "Not implemented"), on .NET's
  `System.IO.Compression`, so `haxe.zip.Reader.unzip` and the zip, EPUB and PNG readers built on
  it run. `windowBits` is zlib's: 15 zlib, -15 raw deflate, 31 gzip, 47 either. The input is
  inflated whole on the first `execute`; feeding it in pieces is not supported.
- `haxe.zip.Compress` works too, the same way: a zlib stream at zlib's levels 0 to 9, so what
  writes compressed data (a KDBX database, a zip, a PNG) runs. The input is compressed whole on the
  first `execute`.
- A generic class reaches a generic interface it implements with another parameter
  (`Foo<Bool>` as `Iface<Dynamic>`, as thenshim's promises do). Haxe 4.3's C# cast forwarder
  passes the class's own parameter, so the cast throws; haxeui-cs corrects the written `.cs`
  for a class that implements the interface with its own parameters in order.
- Pointer and key events bubble natively, as in the DOM; `event.cancel()` stops a pointer event.
  Clicks are made from press and release as a browser makes them: every click is a `CLICK`, and
  the second inside the double-click time is also a `DBL_CLICK`; a middle press and release is a
  `MIDDLE_CLICK`. `pointer-events: none` makes a component and its contents click-through.
- Keys arrive as the browser's key codes. Typed text also fires `KEY_PRESS` (its character code).
  On a Mac, Cmd counts as `ctrlKey` (HaxeUI's `KeyboardEvent` has no meta key). A sideways wheel or
  trackpad swipe arrives as `MOUSE_WHEEL` with `shiftKey` set, which is how ScrollView scrolls across.
- Shadows and filters follow html5's numbers: `drop-shadow` and `box-shadow` shadow the
  component's box (a drop-shadow's angle, strength and quality are ignored, as on html5), and
  `blur`, `grayscale`, `tint`, `brightness`, `contrast`, `saturate`, `hue-rotate` and `invert`
  reach the component and everything in it.
- **`text-shadow: <dx>px <dy>px <blur>px <#rrggbb> [<alpha>]`** is a haxeui-cs directive (core
  has none) that shadows a text's glyphs. Other backends ignore it. `rotation` and
  `clip-path: inset(...)` work as on html5.
- **`line-height: <number> | <n>px | <n>% | normal`** is a haxeui-cs directive too: every line
  of a component's text is that tall, a number or percentage being of the font size, as in CSS.
- `font-name` takes a system family, a CSS generic family (`monospace`, `serif`, `sans-serif`,
  `cursive`, `system-ui`), or a `.ttf`/`.otf` font file: a Haxe resource or a file path.
- Labels show `htmlText`: `b`, `i`, `u`, `s`, `br`, `font` (color, size, face),
  `span style="color: ..."` and `a href`; other tags are dropped and their text kept. Text inputs
  edit plain text: HTML is shown with its tags stripped.
- A link is blue and underlined until a `font` inside it says otherwise, and shows a hand. A click
  on one dispatches **`TextLinkEvent.LINK`** (`haxe.ui.backend.cs`, with `href` and `index`) on
  the component; nothing is followed unless the app listens. The text display
  (`getTextDisplay()`) answers `linkCount()`, `linkHref(i)`, `linkAt(x, y)`, `linkRects()` and
  `lineBoxes()` (each line's top and height, where a page could be cut), in the component's units.
- Images may be PNG, JPEG and the like, or SVG, as a file, a resource, or the SVG markup itself
  (as html5 allows). An SVG is drawn afresh at the size it shows, so it stays sharp.
- `Toolkit.scale` scales the whole UI from the window's top left; sizes and pointer positions
  (`MouseEvent.screenX`) stay in HaxeUI's units. `screenLeft`/`screenTop`, and a root component's
  `left` and `top`, are screen pixels, as core places its drop-down lists, dialogs and tooltips and
  as on heaps. It is taken up as root components are added, and those already up stay where they
  are in pixels.
- Text with no `font-size` from the theme is 13px; html5 leaves it to the browser (usually 16px).
- A `callLater` callback that throws is reported on stderr and the rest of its frame still runs;
  an `onEnd` that throws is reported and the process exits with code 1. A file dialog whose
  listener throws is reported, never thrown.
- Removing (with dispose) a component that has HaxeUI focus quietly drops that focus
  (haxeui-core-joe, `#if cs`).

## Limits

- **Mac is untested.** Avalonia should carry it; Windows and Linux (WSL2 with WSLg) are verified.
  `tests/keys-app` is the by-hand check that Cmd works as Ctrl there.
- **`backdrop-filter` is not drawn.** Avalonia 12 has no way to blur what lies behind a control:
  it offers no backdrop effect, and a `VisualBrush` of the window drawn inside that same window
  recurses without end.
- Text in a box too narrow for one letter is not shown; html5 breaks it one letter per line.
- Dashed and dotted borders whose sides differ are drawn square at the corners (a uniform dashed
  border does follow the radius).
- Changing `Toolkit.scale` after the app has started shows from the next root component added.
- Core's notifications and windows place themselves from `Screen.width` (units, not pixels), so
  at a scale other than 1 they stop short of the right and bottom edges, as on heaps.
- `letter-spacing` is not a style haxeui-core has, so no backend draws it (`line-height` is a
  haxeui-cs directive, above).
- Haxe's C# target puts its top-level classes in the global namespace, so native code writes
  `System.Math` and `System.Array`. `-D erase-generics` breaks HaxeUI.
