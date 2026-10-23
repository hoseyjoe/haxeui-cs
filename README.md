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
- haxelibs: `haxeui-core` (haxeui-core-joe), `haxeui-cs` (this repo: `haxelib dev haxeui-cs D:/_github/haxeui-cs`)

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

| Define | Effect |
|---|---|
| `-D haxeui_cs_run` | run the program straight after building it |
| `-D haxeui_cs_headless` | headless Avalonia (real Skia drawing, no OS window) plus `haxe.ui.backend.cs.TestDriver`, for tests |
| `-D haxeui_cs_no_dotnet` | stop after writing the `.csproj` |
| `-debug` | console `Exe` instead of `WinExe` (headless builds are always `Exe`) |

`haxe.ui.backend.cs.WindowCapture.save(path)` photographs the window, desktop or headless.

## Testing

`haxe tests/headless.hxml` builds and runs the backend's own suite headlessly (add
`-D test=<Case>` for one case, `-D UTEST_PATTERN=<test>` for one test). `TestDriver` pumps the
dispatcher, injects clicks, wheel, keys and typing at window coordinates, and reads back rendered
pixels. `haxe tests/exit-app/build.hxml` is the desktop check: a real window, a repeating
`haxe.Timer`, and the process must exit by itself when the window closes.

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
- Canvas fills follow haxeui-heaps (Flash): `fillStyle(c)` begins a fill and `fillStyle(null)`
  ends it, and the path drawn in between is filled even without `beginPath`.
- Pointer and key events bubble natively, as in the DOM; `event.cancel()` stops a pointer event.
- Removing (with dispose) a component that has HaxeUI focus quietly drops that focus
  (haxeui-core-joe, `#if cs`).

## Limits (v1)

- **Fonts are system fonts, by family name.** A `font-name` that looks like a file is ignored.
- Verified on **Windows** only; Avalonia should carry Mac and Linux, untested.
- No text shadows, no `Toolkit.scale` (Avalonia's own DPI scaling applies), no CSS filters.
- Haxe's C# target puts its top-level classes in the global namespace, so native code writes
  `System.Math` and `System.Array`. `-D erase-generics` breaks HaxeUI.
