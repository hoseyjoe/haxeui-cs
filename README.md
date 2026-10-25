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
`--macro haxe.ui.backend.cs.macros.Build.addPackage("Microsoft.Data.Sqlite", "10.0.0")`.

| Define | Effect |
|---|---|
| `-D haxeui_cs_run` | run the program straight after building it |
| `-D haxeui_cs_headless` | headless Avalonia (real Skia drawing, no OS window) plus `haxe.ui.backend.cs.TestDriver`, for tests |
| `-D haxeui_cs_no_dotnet` | stop after writing the `.csproj` |
| `-D haxeui_cs_publish=<rid>` | publish a release build as one self-contained file instead (see Publishing) |
| `-debug` | console `Exe` instead of `WinExe` (headless builds are always `Exe`) |

`haxe.ui.backend.cs.WindowCapture.save(path)` photographs the window, desktop or headless.

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

- It is about 100 MB. `-p:EnableCompressionInSingleFile=true` (by hand) makes it smaller and
  slower to start.
- It is not trimmed, and should not be (`PublishTrimmed`): Haxe's output and HaxeUI find classes by
  name at run time.
- `Sys.programPath()` is an empty string in a single-file program (Haxe's own `Sys`; .NET warns
  about it while publishing). For the program's own folder use
  `cs.Syntax.code("System.AppContext.BaseDirectory")`. Relative paths are still relative to the
  folder it was started from.
- The native libraries are unpacked to a temporary folder the first time it runs.
- For a Mac it is a plain program, not a signed `.app` bundle. On Linux a real window needs the
  libraries in the Linux section below.

## Testing

`haxe tests/headless.hxml` builds and runs the backend's own suite headlessly (add
`-D test=<Case>` for one case, `-D UTEST_PATTERN=<test>` for one test). `TestDriver` pumps the
dispatcher, injects clicks, wheel, keys and typing at window coordinates, and reads back rendered
pixels. `haxe tests/exit-app/build.hxml` is the desktop check: a real window, a repeating
`haxe.Timer`, and the process must exit by itself when the window closes.
`haxe tests/early-add/build.hxml` checks that a component added before the window exists (as
HaxeUIApp's preloader is) appears once it does. `haxe tests/window-app/build.hxml` opens a window
with every window option, checks an idle app stays idle, and ends itself with `app.exit()`.

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

- `callLater` runs with the next frame (about 60 a second), as html5's `requestAnimationFrame`.
  Haxe's own event loop (`haxe.Timer`, `haxe.MainLoop`) runs when it next needs to and straight
  after any frame, input or timer; an idle app is woken about four times a second, not a hundred.
- Canvas drawing follows haxeui-heaps (h2d.Graphics): `fillStyle(c)` begins a fill and
  `fillStyle(null)` ends it, and the path drawn in between is filled even without `beginPath`.
  Each `moveTo` starts a new polygon, filled on its own and then outlined, in drawing order: a
  later shape covers an earlier outline, and overlapping polygons of one fill cut no holes.
- `StringTools.startsWith` and `endsWith` compare code unit by code unit, as on every other
  target. Haxe's C# std leaves them to .NET's culture rules, where a BOM or soft hyphen matches
  anything; haxeui-cs corrects that at compile time.
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
- `font-name` takes a system family, a CSS generic family (`monospace`, `serif`, `sans-serif`,
  `cursive`, `system-ui`), or a `.ttf`/`.otf` font file: a Haxe resource or a file path.
- Labels show `htmlText`: `b`, `i`, `u`, `s`, `br`, `font` (color, size, face) and
  `span style="color: ..."`; other tags are dropped and their text kept. Text inputs edit plain
  text: HTML is shown with its tags stripped.
- Images may be PNG, JPEG and the like, or SVG, as a file, a resource, or the SVG markup itself
  (as html5 allows). An SVG is drawn afresh at the size it shows, so it stays sharp.
- `Toolkit.scale` scales the whole UI from the window's top left; sizes and pointer positions stay
  in HaxeUI's units. It is taken up as root components are added.
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
- `letter-spacing` and `line-height` are not styles haxeui-core has, so no backend draws them.
- Haxe's C# target puts its top-level classes in the global namespace, so native code writes
  `System.Math` and `System.Array`. `-D erase-generics` breaks HaxeUI.
