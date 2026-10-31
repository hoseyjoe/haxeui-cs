# haxeui-cs with no native C#

Date: 2026-10-31

## Why

Joe doesn't want haxeui-cs to rely on native code, because that makes every app built on it use a
C# project. An app author should be able to write an `.hxml` and Haxe, run the compiler, and get a
program that runs.

## What Joe decided

- Avoid native code, so that an app doesn't need a C# project.
- Keep both compilers: Haxe 4.3.7's C# target and hxc's `-D dotnet` (IL) target, from one source.

Everything else here is the author's call, shown to Joe in summary before this was written, and is
marked in "Calls made for Joe to check".

## Goals

1. The 17 files of `native/*.cs` (about 3,800 non-blank lines) become Haxe in the haxelib. The library
   has no handwritten C# left that an app compiles.
2. Under hxc, the app author sees no project: `hxc app.hxml` leaves a folder holding the app, Avalonia
   and its native libraries, which `dotnet App.dll` runs. As today, a folder built on Windows runs on
   Linux as it is. Internally a throwaway project supplies the libraries (see below), and it never
   compiles the app.
3. Under Haxe 4.3.7, an app builds as it does today. It still has a generated `.csproj`, since that
   compiler's output is C#, but no `native/*.cs` goes into it.
4. Behaviour doesn't change. Each public behaviour in the README stays as it is, and the tests pass
   under both compilers.

## Non-goals

- Android without a project. The APK build needs .NET's Android tooling and a project. It stays on
  the Haxe 4.3.7 route with its generated `.csproj` and `templates/android/MainActivity.cs`.
- Publishing under hxc. `haxeui_cs_publish` stays refused there, so an hxc app ships as its folder
  until a later project looks at single-file builds and trimming.
- Porting an app's own C#. `addNative` and `addPackage` keep working on the Haxe 4.3.7 route and stay
  ignored under hxc. JoeClash's `src-cs/native/H2d.cs` and `tests/clipboard-app/Win32Clipboard.cs` are
  not touched.
- Redesigning the layer. This is a port, so no merging it into the `*Impl.hx` files and no API tidying.

## Anti-goals

These would make it a failure even if it builds:

- C# moved into Haxe strings. `cs.Syntax.code` and `untyped` are not the way across.
- Silent differences between the compilers. A case the two handle differently must fail a test.
- `#if` forks of whole classes per compiler. A small `#if dotnet` at one call site is acceptable only
  where this document names it.
- Slower paint or input on Android without anyone noticing.

## What the probes showed

Throwaway probes built one Haxe source under both compilers and ran it on .NET 10, with real Avalonia
12.1.4 classes and a real headless window. hxc's DLL also ran in place of the DLL in a throwaway
project's output folder: on Windows, through that folder's `.exe`, and, with the same folder, on Linux
under WSL.

Works on both, and ran unless marked:

| Shape | How |
|---|---|
| Avalonia types | hand-written `@:native` externs, as `Native.hx` already does |
| Subclass of a control or `Application` | `@:nativeGen class`, with public and `@:protected` overrides |
| Handler from a Haxe function | hxcs's `cs.system.EventHandler_1`, `Action_1`, `Func_1`: assign the function to one |
| C# event | `@:event private var X` with `add_X`, `remove_X` on the extern |
| Routed handler | `@:overload AddHandler(RoutedEventBase, cs.system.Delegate, routes, handled)`, with the `*Event` statics typed as the non-generic base, and the delegate passed with `cast` |
| .NET enum | `extern enum` |
| Indexer (`Children[i]`) | `extern class X implements ArrayAccess<T>` |
| `out` | `cs.Out<T>` |
| `in` (compiled, not run) | `cs.Ref<T>` with `@:overload` |
| `Task` continuation | `task.ContinueWith(action)` |
| Skia, headless start | static calls on the extension classes, such as `SkiaApplicationExtensions.UseSkia(builder)` |

Doesn't work on either:

- `--net-lib` of Avalonia for Haxe code to see. It stops on .NET types such as `Vector2` and
  `ReadOnlySpan_1`. hxc needs the DLLs passed to resolve externs, but Haxe code must use externs.
- Writing a delegate abstract by hand with `untyped __delegate__`.
- Generic `AddHandler<T>` on Haxe 4.3.7, whose C# erases `T` to `object` (CS0030).

`-D net-ver=45` was needed for `Func_1`. The default reference set has no `System.Func`.

## hxc fixes needed first

All four are in hxc.

1. **Property override, silent.** `@:protected @:property override function get_StyleKeyOverride()`
   compiles under hxc, and the DLL has no such property. Haxe 4.3.7 writes a real
   `protected override System.Type StyleKeyOverride`. Needed by `UITextInput` and `UIFonts.LoadedFonts`
   (`Key`). The fix must make hxc write the property, or refuse with an error.
2. **Interface property, refused.** `TclassToIl.hx:883` refuses a class implementing a property of a
   hand-written extern interface. Haxe 4.3.7 builds and runs this. Needed by `UILayers.Draw`
   (`ICustomDrawOperation.Bounds`).
3. **Generic method taking a delegate.** "hxc cannot tell whether the .NET method … accepts" for
   `AppBuilder.Configure<TApp>(Func<TApp>)`. Until then, a `#if dotnet` in the one place that starts
   Avalonia calls `Configure<TApp>()` through reflection, which ran. This is the one named `#if`.
4. **`Compiler.addNativeLib`.** `EvalStdLib.hx:3551` always throws "does not support native libraries",
   and `registerNativeLibs` handles the command line's libraries on its own path, so timing needs a look.
   An init macro has to be able to add `--net-lib` under `-D dotnet`, or an app's `.hxml` would have to
   list every DLL by path, which goal 2 rules out.

## How the port is laid out

- A new folder of Haxe classes, one module per C# file, under `haxe/ui/backend/cs/native/`, and
  `Native.hx` shrinks to re-exports or goes. The package keeps the rule that it knows nothing of HaxeUI.
- Each class keeps its .NET name with `@:native("HaxeUICs.X")` and its C# member names, and is
  `@:nativeGen`. So `MainActivity.cs`, which names `HaxeUICs.Host` and `HaxeUICs.HostApplication`, and
  the `*Impl.hx` callers don't change.
- Avalonia, SkiaSharp and Svg.Skia externs go in a package of their own, declaring only what's used.
- `Callbacks.hx` and the listener interfaces (`ICallback`, `IPanelListener` and so on) stay. Removing
  them would be a cleanup, and it can come after.
- `cs.Syntax.code` in `PlatformImpl.hx` and `OrdinalStringTools.hx` is replaced by externs, for the
  same reason as the rest.
- `-D net-ver=45` goes in `extraParams.hxml`, if the suite stays green with it.

### File notes

| File | What needs care |
|---|---|
| `ColorMatrix` | `uint` and `byte` arithmetic in the pixel loop, `Marshal.Copy`, and `ConditionalWeakTable` needing a hand-written generic extern. It has tests to compare against. |
| `Deflate`, `Inflate` | Small, and `NativeCompress` and `NativeUncompress` keep calling them. |
| `FileDialogs` | `await` becomes continuations that return to the UI thread. `async void`'s rule stays: nothing thrown ever reaches the dispatcher. `OpenOnAndroid`'s copy runs off the UI thread. |
| `Host` | The `#if ANDROID` and `HAXEUI_CS_HEADLESS` blocks become `haxeui_cs_android` and `haxeui_cs_headless`. `Entry`, `LeaveApp` and `FinishApp` stay assignable from C#, because `MainActivity` sets them before Haxe's `main`. |
| `PickedFiles` | `FailingStream` overrides `Read(Span<byte>)`, which Haxe can't declare. It's a test double, so it can be written without that override if the code under test reads through `Read(byte[], ...)`. Otherwise it needs another approach. |
| `TestDriver` | Headless only, and `Build.hx`'s exclusion becomes a `#if`. The HTTP test server's `await`s become continuations or a plain thread. |
| `UIClipboard` | The nested dispatcher frame stays. `task.Result` on `Task<T>` needs a generic extern, and `Contains` is a LINQ extension called as a static. |
| `UIEvents` | The largest user of routed handlers, about 12 `AddHandler` calls. `EventRouter` and `ClickState` stay internal in spirit. |
| `UIFonts` | `Dictionary.TryGetValue`, and `LoadedFonts` needs hxc fix 1, and calls the protected `TryAddGlyphTypeface` with `out`. |
| `UIGraphics`, `UIImage`, `UIStyle` | Plain drawing calls through externs. |
| `UILayers` | `Draw` runs on the render thread. It must stay free of `Dynamic`, `trace` and anything that lazily initialises Haxe state. `using` becomes `try`/`finally` with `Dispose`. `TryGetFeature<T>()` becomes the public `TryGetFeature(Type)`, and the span overload of `SKImage.FromPixelCopy` becomes its `byte[]` one. |
| `UIPanel` | Implements `ICustomHitTest`, and `Rect?` becomes a flag or a Haxe-side null, staying inside the class. |
| `UIText`, `UITextInput` | Protected overrides, and `UITextInput` needs hxc fix 1. |

### Traps the port must respect

- `Null<Rect>` in Haxe is `haxe.lang.Null<T>`, not `System.Nullable<T>`, so a real `T?` in an Avalonia
  signature needs `cs.system.Nullable_1`. `ulong?` from `GetBasicPropertiesAsync` is one.
- Haxe's `foreach` doesn't cover .NET enumerables: index, or use `GetEnumerator`.
- A Haxe class's statics initialise on first use, and on Android `AndroidApp.OnCreate` touches `Host`
  before `cs.Boot.init()` runs in `MainActivity.RunHaxe`. Check that this still holds.
- `catch (e:cs.system.Exception)` must keep catching what `catch (System.Exception)` did, including
  Haxe's own thrown values, in the places that promise never to let anything escape.
- hxc pins exact extern signatures, so an extern that happens to compile under C# may be refused or
  bind differently. Fix the extern to match the real signature.

## Getting Avalonia without a project

Under hxc, `Build.hx` provides what `App.csproj` gives today. On a build, before typing:

1. Work out the package set: `Avalonia`, `Avalonia.Desktop`, `Avalonia.Themes.Simple`, `Svg.Skia`, and
   `Avalonia.Headless` when headless, at the versions already in `Build.hx`.
2. If that set isn't cached, generate a throwaway project outside the app's folders, with an empty
   entry point and `AssemblyName` set to the app's name, and `dotnet build` it. hxc already needs the
   .NET SDK for its reference pack, so this adds no new requirement.
3. Add `--net-lib` for each managed DLL in its output, with `Compiler.addNativeLib` (hxc fix 4).
4. After generating, copy the project's output into the app's folder and overwrite its placeholder
   `App.dll` and `App.runtimeconfig.json` with hxc's.

That folder is the build's result. Its `App.deps.json` and `runtimes/` tree are what keep a folder built
on Windows running on Linux, and it has the launcher `App.exe`. `--net-lib` and the runtime read the same
copies, so they agree on versions. `OutputType` follows today's rule: `WinExe` unless headless or `-debug`.

Because `deps.json` names the app, the cache either holds one output per app name or `Build.hx` rewrites
that file. That's left to the builder.

## How it's checked

- `tests/headless.hxml` keeps its current meaning under Haxe 4.3.7. A second hxml builds the same suite
  under hxc with `-D dotnet`. "Passes on both" is on Windows until the end of the port. The gate for each
  step is in "Order of work".
- At the end, hxc's Windows-built output runs on Linux under WSL: the whole headless suite, and the small
  apps in a real window, as the Linux section of the README records today. The Mac stays with the open
  Mac check, under whichever compiler is ready when Joe's Mac is available.
- The tests that build small apps (`exit-app`, `window-app`, `early-add`, `keys-app`) run under both.
- `tools/gallery` is built under both and compared with the current pictures, to catch rendering drift
  no assertion sees. `compare.py` already compares cs with html5.
- An Android build of `tests/android-app` still builds and starts.
- Timings on the device, as in the Android performance work: a chapter crossing in EpubReader, against
  a build of today's `native/*.cs` kept for the purpose. Check that the two builds differ. Take them
  twice: once `UIPanel` and `UIGraphics` are ported, and at the end. A chapter crossing more than 10%
  slower stops the port for a tuning pass. If tuning can't bring it back, it goes to Joe before
  `native/*.cs` is removed. Anything smaller is reported with the numbers.
- A test or a grep gate confirms no `.cs` file is left in `native/` and no `cs.Syntax` or `untyped` in
  `haxe/`, apart from `#if` sites this document names.

## Order of work

1. Make the four hxc fixes, each with hxc's own tests.
2. Build the current suite under hxc against prebuilt `native/*.cs`, as the README describes, and run
   it. This gives the hxc baseline before any file moves, and finds any hxc gap unrelated to this port
   while it's cheap. Fix those first.
3. Port the files, leaf first: `Deflate`/`Inflate`, `ColorMatrix`, then the rest by dependency, with
   `Host` and `TestDriver` late.
4. Add the Avalonia fetch to `Build.hx`, and turn on the full suite under hxc.
5. Update the README, and remove the `native/` and two-stage sections.

### The gate during the port

The suite can't stay green on both compilers after each file. Under hxc, C# that's left has to be
prebuilt before Haxe compiles, so it can't refer to a class that now exists only in hxc's output. Eight
files (`Host`, `UIPanel`, `UIStyle`, `UIImage`, `UIGraphics`, `UIText`, `UIEvents`, `UIClipboard`, about
2,490 of the 3,800 lines) also refer to each other in a cycle. So:

- **Each step:** the full suite passes under Haxe 4.3.7, where the remaining C# and the generated C# are
  one assembly, so any order works and each commit can stay small, one file at a time, cycle included.
- **Each step, while it's possible:** hxc compiles the ported classes on their own, with a small
  smoke program. Leaf-first means they refer only to each other and Avalonia. This stops when the cycle
  begins and resumes when it closes.
- **Once the last C# is gone:** the full suite passes under hxc, then the end-of-port checks run.

hxc problems in the cycle therefore surface late and together. Step 2's baseline and the probes reduce
that risk, and the cycle's ported classes are also compiled under hxc as soon as it closes, before anything
else moves.

## Risks

- The ported code may be slower in hot paths, because Haxe's output adds casts and boxing where it can't
  see a type. Typed code and `@:nativeGen` should keep this small, but it's unmeasured.
- A shape not probed may need another `hxc` fix. Each one seen so far has been small, and hxc has been
  fixed quickly, so this should cost time and not block the work.
- The Android route's trim and AOT settings may treat Haxe-generated classes differently from C#.
- The probes haven't covered real file dialogs, a window on a real desktop, or the render-thread path
  actually drawing.

## Calls made for Joe to check

1. hxc gets the fixes, not the port working around them, and hxc's fixes land before the port. The
   existing commit policy doesn't cover hxc, so the plan must ask Joe where those commits go.
2. Android and publishing keep a generated project, and publishing is refused under hxc for now.
3. `addNative` stays. An app's own C# isn't ported, and neither is the test helper `Win32Clipboard.cs`.
4. Libraries come from a hidden throwaway project built under the app's name, rather than haxeui-cs
   downloading from NuGet itself. It keeps a Windows-built folder running on Linux, and gives an `.exe`.
5. It's a port that keeps its .NET names and C# member names, so a later cleanup can Haxe-ify them.
6. The gate during the port: Haxe 4.3.7's full suite at every step, and hxc's full suite only when the
   last C# is gone. This gives small commits at the price of finding some hxc problems late.
7. A chapter crossing more than 10% slower on the device stops the port for tuning, checked midway and
   at the end. This needs Joe's phone at both points.

## Left to the builder

- The exact extern package name and file layout, and whether `Native.hx` stays as re-exports.
- Whether a thread or continuations replace the test server's `await`s.
- The cache location for the throwaway project's output, and how it handles the app's name.
- How `FailingStream` is finally solved, within the anti-goals.
