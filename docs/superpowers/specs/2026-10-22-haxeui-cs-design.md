# haxeui-cs — design

> Paths are placeholders for the checkouts this was written against: `<haxeui-cs>` (this repo), `<haxeui-core-joe>` and `<haxeui-html5>` (haxelib checkouts), `<JoeClash>` and its worktrees `<JoeClash-cs>` and `<JoeClash-gate>`.

Date: 2026-10-22. Status: draft, awaiting Joe's approval.

Calls marked **[builder's call]** are Claude's, not Joe's. Everything else was
decided with Joe in conversation.

## Intent

A real HaxeUI backend for .NET. A HaxeUI app compiles with Haxe's C# target into
an ordinary .NET desktop program that renders through Avalonia. Joe wants to ship
HaxeUI desktop apps the way people use Electron (one codebase, a normal
installable desktop program) but with HaxeUI as the front end, no bundled web
browser, and access to .NET libraries.

The first real app on it is **Joeditor**, JoeClash's story-script editor
(`<JoeClash>\tools\Joeditor`, about 10,600 lines). "Done" for v1 means
Joeditor runs on haxeui-cs.

## Goals (v1)

1. `haxeui-cs` is a haxelib at `<haxeui-cs>`. With it, a HaxeUI app built
   against **haxeui-core-joe** compiles to C# and runs as a .NET 10 desktop app
   using Avalonia, from one `haxe <file>.hxml` command.
2. It is a **composite** backend. Each HaxeUI component is a plain Avalonia
   element. HaxeUI does layout, styling and theming itself, as haxeui-html5 and
   haxeui-openfl do. Apps look the same on every OS.
3. It supports every HaxeUI feature Joeditor uses:
   - **layout:** `vbox`, `hbox`, `box`, `absolute`, `scrollview`,
     `horizontalsplitter` (check `EditorView`'s markup for anything this list
     misses)
   - **controls:** `label`, `button`, `dropdown`, `textfield`, `textarea`,
     `number-stepper`, `image`, `treeview`, `canvas` (HaxeUI's drawing API)
   - **dialogs:** `MessageBox`, `Dialogs.openFile` / save-file dialogs
   - **other:** tooltips; mouse, keyboard and focus events; `haxe.ui.util.Timer`;
     `ArrayDataSource`; item renderers; styles via CSS (`UiCss`-style stylesheets)
4. Joeditor launches on Windows from a new `tools.joeditor.cs.hxml`. It opens a
   `.lor`, shows the story tree and the map view, edits field values and panel
   text, and saves correctly.
5. Joeditor's existing Heaps builds, and every other JoeClash and haxeui-core-joe
   build, keep compiling and working unchanged.

## Non-goals (v1)

- **The JoeClash game itself.** It is built on Heaps, which has no C# target.
- **Joeditor's figure pane.** `FigurePane` draws with a raw `h2d.Graphics` and the
  game's `view.SvgRenderer`. Under haxeui-cs it shows a placeholder. Porting it
  is later work.
- **Joenimating's Animate pane.** `EditorView` embeds joenimating's
  `ui.EditorView` (the Preview/Animate column). Its stage, font and timeline are
  Heaps-only (`h2d.Graphics`, `hxd.Res`/`SDFFonts`, `MouseHelper`). It is deferred
  like `FigurePane`:
  - the C# hxml drops `-lib joenimating`;
  - `EditorView` guards the pane and its Save and dirty-title hooks
    (`anim.isDirty()`, `anim.save()`) under `#if !haxeui_cs`;
  - selecting a cast member with a portrait shows a placeholder instead;
  - the joenimating repo is not touched.

  **[builder's call]**, consistent with deferring `FigurePane`.
- **Testing on Mac and Linux.** Avalonia should make them work, but v1 is verified
  on Windows only.
- **Custom font files**, including Joeditor's SDF bitmap `GameFont`. v1 uses system
  fonts by name, with size, bold, italic, underline and colour. **[builder's call]**
- **haxeui3-core.** It was considered and rejected for now (see Decisions). The
  layering below keeps a later haxeui3 backend possible.
- **A native-controls backend**, where a HaxeUI Button would become an Avalonia
  Button.
- **Packaging and installers.** v1 produces a runnable build folder.

## Anti-goals (a failure even if it technically works)

- Breaking haxeui-core-joe for its other backends (html5, heaps, openfl), or
  breaking any JoeClash build. Every core and JoeClash change must be guarded
  (`#if cs` / `#if haxeui_cs`) or be correct on every target.
- Forking HaxeUI core logic into the backend to get around a core bug. Fix it in
  haxeui-core-joe instead. It is Joe's fork, and that is why it was chosen.
- A build that needs hand steps between `haxe` and running the app.

## Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Runtime | Haxe 4.3.7 C# target, .NET 10, Avalonia 12.1.4 | Avalonia covers Windows, Mac and Linux; Joe wants all three "if possible". Haxe 5 drops the C# target, so this stays on 4.3.x. |
| Core | haxeui-core-joe (`<haxeui-core-joe>`, Joe's fork) | It has the full component set; it is Joe's, so C# fixes land directly; less C# generics trouble. haxeui3 is a proof-of-concept that lacks text fields, dropdowns, menus and dialogs. |
| Backend style | composite | |
| First app | Joeditor | |

## Spike findings

From `spike/`, which is throwaway.

- Haxe `-cs out -D no-compilation` plus an SDK-style `.csproj` that compiles
  `out/src/**/*.cs` against Avalonia NuGet packages produced a window with Haxe
  content on .NET 10. A render to PNG confirmed it. Do **not** use `-net-lib` or
  hxcs's own build: they target the old .NET Framework toolchain.
- Hand-written externs (`@:native("Avalonia.Controls.Canvas") extern class …`)
  work for properties, constructors and statics. `cs.Syntax.code` covers C# events
  (`x.PointerPressed += (s, e) => {0}.onX(e)`), extension methods and generic
  methods.
- Haxe 4.3 puts top-level classes in the global C# namespace (`global::Main`).
- Haxe resources (HaxeUI stores its component class map this way) must be
  embedded:
  `<EmbeddedResource Include="out/src/Resources/*" LogicalName="Resources.%(Filename)%(Extension)" />`.
- `#line` directives make C# compiler errors point at `.hx` lines.
- **Core bug found:** `haxe/ui/util/FunctionArray.hx` `indexOf` uses
  `Reflect.compareMethods` only `#if neko`. On C# every method reference is a
  fresh closure object, so `==` never matches and `ComponentBase.checkWatchForMoveEvents`
  recurses forever. The fix is `#if (neko || cs)`. Expect more fixes of this kind.
- `-D erase-generics` breaks HaxeUI's `EventType<T:UIEvent>`. Don't use it.
- TextBlock measurement works: `Measure(Size.Infinity)` → `DesiredSize`.

## Architecture

Two layers in one haxelib.

1. **Avalonia layer.** This layer knows nothing about HaxeUI's API.
   - Externs for the Avalonia types used, in package `avalonia.*` mirroring .NET
     namespaces.
   - A small set of hand-written C# files shipped in the haxelib (for example
     `native/*.cs`) and compiled into the app by the generated `.csproj`:
     - a custom panel control that draws a component's background, border, radius
       and background image (with 9-slice), clips, and positions children absolutely;
     - an app/host bootstrap;
     - event forwarding into Haxe through a small interface that the Haxe side
       implements.
   - Rendering code lives in C#, where Avalonia's `DrawingContext` API is natural.
     **[builder's call]**
   - The aim is that a future haxeui3 backend could reuse this layer unchanged.
2. **HaxeUI layer.** `haxe/ui/backend/*Impl.hx`: the 20 files haxeui-core-joe
   expects. haxeui-blank lists the full set, and haxeui-html5 is the reference
   for behaviour.

### Contract mapping (guide, not prescription)

| HaxeUI piece | Avalonia |
|---|---|
| `AppImpl` | Start Avalonia (`AppBuilder…StartWithClassicDesktopLifetime`, which blocks until exit), create the main `Window`, call `onReady` from `OnFrameworkInitializationCompleted`, call `onEnd` on shutdown. |
| `ScreenImpl` | The main window's root panel. Width and height come from the client size, with resize forwarded. Handles title and window-level mouse and key mapping. |
| `ComponentImpl` | Owns one custom panel. `handlePosition` and `handleSize` set the panel's position and size, `handleClipRect` clips, `handleVisibility` and `handleDisabled` toggle, `applyStyle` hands style values to the panel, and `mapEvent`/`unmapEvent` subscribe and unsubscribe pointer, wheel, key and focus events. Composition (the component *has* a panel) rather than inheritance. **[builder's call]** |
| `TextDisplayImpl` | `TextBlock`; `measureText` via `Measure`. |
| `TextInputImpl` | `TextBox`, single and multi-line, with chrome stripped (transparent, no border) so HaxeUI's styling shows, as html5 does with `<input>`. Caret and selection are mapped. |
| `ImageDisplayImpl` / `ImageData` | `Bitmap` decoded from bytes; HaxeUI scale modes. |
| `ComponentGraphicsImpl` | Records draw commands that the panel replays in `Render`. **Fill semantics follow Joe's haxeui-heaps fork** (Flash-style): `fillStyle(c)` begins a fill, `fillStyle(null)` ends it, and the `moveTo`/`lineTo` path drawn in between is filled even without `beginPath`. Joeditor's `MapView` (coastline, islands, fork diamonds) depends on this. html5's SVG implementation would leave those polygons unfilled. **[builder's call]** |
| `TimerImpl` / `CallLaterImpl` | `DispatcherTimer` / `Dispatcher.UIThread.Post`. |
| `haxe.Timer` | On C#, Haxe timers run on the main thread's event queue, which Avalonia's loop starves. Pump it (for example from a `DispatcherTimer`) so `haxe.Timer` users such as `Animation` and `ListView` work. First check whether Haxe's generated entry point already runs it. |
| `OpenFileDialogImpl` / `SaveFileDialogImpl` | Avalonia `StorageProvider` pickers (async), with the result delivered back on the UI thread. |
| `AssetsImpl` | Images and text from Haxe resources and files. Fonts: system fonts by name only (see Non-goals). |
| `PlatformImpl` | Metrics such as scrollbar size, system locale, colours. |
| DPI | Avalonia's own scaling. HaxeUI works in device-independent units. `EditorScale.detect` is `#if hl` and returns 1.0 on C#, which is correct here. |

**Behaviour reference.** Use haxeui-html5 in general. Where Joeditor depends on
haxeui-heaps behaviour (canvas fills, above), match heaps. The bar for Joeditor
is "correct and usable", not pixel parity with the Heaps build: system fonts
already rule that out. Small Joeditor layout tweaks under `#if haxeui_cs` are
fine. `TextInputImpl.selectionColor` (a static Joeditor sets, which only heaps
has) is provided by haxeui-cs as a harmless compatible static, so Joeditor needs
no guard for it. **[builder's call]**

### Build pipeline

**[builder's call]**, modelled on Joe's `winui3` haxelib, which hooks a macro into
the build the same way.

- `haxeui-cs/haxelib.json` depends on `haxeui-core`.
- `extraParams.hxml` adds `-D no-compilation` and
  `--macro haxe.ui.backend.cs.macros.Build.configure()`.
- After Haxe generates code, that macro does three things:
  1. writes `<cs-out>/<Main>.csproj` from a template (net10.0, Avalonia packages,
     `src/**/*.cs`, the haxelib's `native/*.cs`, embedded `src/Resources/*`,
     the spike's `NoWarn` list);
  2. runs `dotnet build`;
  3. if `-D haxeui_cs_run` is set, launches the app.
- The app's own `.hxml` stays ordinary:
  `-lib haxeui-core -lib haxeui-cs -main X -cs bin/cs`.
- A `module.xml` (and native/properties config, where needed) is placed as in
  haxeui-html5, so `ModuleMacros` finds it.

## Changes outside this repo

Both repos are Joe's.

1. **haxeui-core-joe.** Minimal C#-correctness fixes found while bringing up
   components, starting with `FunctionArray`. Each fix is guarded or correct on
   all targets, and each gets one line in the final summary.
2. **JoeClash.**
   - `tools.joeditor.cs.hxml`.
   - The C# hxml drops `-lib joenimating` (see Non-goals) and whatever else
     only the Heaps build needs.
   - `#if haxeui_cs` alternatives in Joeditor for:
     - `EditorFont` (SDF font → system font);
     - `FigurePane` (placeholder; no `h2d`/`SvgRenderer` import in the C# build);
     - the Animate pane wiring in `EditorView` (see Non-goals);
     - `MapView`'s `h2d.Text` shadow reach-through (drop the shadow);
     - `EditorRes` / `hxd.Res` resource loading, including the icon copy
       `EditorRes.gather` does for joenimating;
     - `Joeditor.hx`'s `--shot` / `--resize` paths (`h3d.Engine`,
       `hxd.Window`): compiled out for C#.
   - Joeditor's `#if lay_debug` harness (`--press`, `--tip`, `--drag`, `--move`,
     `MouseHelper`, `hxd.Window`) is **not** ported. It stays Heaps-only and
     compiles out of the C# build.
   - `loreline` already ships C# builds upstream, so it should compile as is.
   - Follow JoeClash's `CLAUDE.md` conventions for any edit there.
   - Whatever Joeditor pulls in (`loreline`, `data.*`) has to compile to C#. Fix
     it with the smallest guarded change if it doesn't.

**Repos and commits** (Joe's answer). **Nothing is pushed anywhere.**

- **haxeui-cs** is a git repo. Commit as work goes.
- **JoeClash:** all edits happen in a **separate git worktree on a new branch**.
  Joe's own checkout (on `main`, with his uncommitted work) is never touched.
  Commits go on that branch, and merging waits for Joe.
- **haxeui-core-joe:** C#-correctness fixes are committed **straight to
  `master`** as small commits. `haxelib dev` points every HaxeUI build on the
  machine at this one checkout, so a branch would switch them all. Each fix must
  be `#if cs`-guarded or correct on every target.

## Verification

- **Backend test app** (`haxeui-cs/tests/`): one screen per component and feature
  Joeditor uses. It renders headlessly or to PNG, so results can be checked
  without a person clicking. Avalonia.Headless is the candidate. The tests use
  synthetic input for clicks, typing and wheel.
- **haxeui-cs gets a small test-support API**, so verification needs no person
  clicking:
  - inject a pointer, wheel or key event at screen coordinates;
  - capture the window to PNG.

  It runs in a real window, or under Avalonia.Headless if that proves practical.
  **[builder's call]**
- **Joeditor acceptance on Windows.** The builder runs it unattended through that
  API, then Joe does a final click-through himself. Build `tools.joeditor.cs.hxml`,
  then:
  1. copy a real `.lor` from `JoeClash/story/` (Joeditor's Save overwrites the
     file it opened);
  2. open the copy and check the tree and the map view (filled coastline and
     islands);
  3. select nodes, edit a field and some panel text;
  4. Save;
  5. diff the copy against the original, and check that only the intended spans
     changed.
- **No regressions:**
  - `tools.joeditor.hxml` and `build.hxml` (Heaps) still build;
  - haxeui-core-joe's changes compile for html5 and heaps (an existing JoeClash
    build covers heaps).

## Risks and unknowns

- More C#-only core bugs, like the closure-equality one. They're expected; budget
  for them.
- `loreline` and game `data.*` code on C#: untested.
- HaxeUI's reflection (`Type.createInstance` / `resolveClass` in about 27 files)
  vs dead-code elimination. The C# build may need `@:keep` or `-dce std`.
- Text metrics differ from Heaps, so Joeditor's layout may need tuning.
- Avalonia 12 API details: check against the restored assemblies, not memory.
- Performance of Dynamic-heavy HaxeUI code on .NET: probably fine for an editor.

## Left to the builder

- File and package layout inside the haxelib.
- Extern coverage, and the exact C#/Haxe split in the Avalonia layer.
- Test harness mechanics.
- Exe vs WinExe and other `.csproj` details.
- Event mapping details.
- The order in which components are brought up.
