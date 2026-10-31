# haxeui-cs With No Native C# Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `native/*.cs` becomes Haxe compiled by both Haxe 4.3.7 and hxc, so an hxc app needs no visible C# project, and everything an app sees behaves as it does today.

**Architecture:** Four hxc fixes come first. Then the files move leaf-first into `@:nativeGen` Haxe classes that keep their .NET names (`@:native("HaxeUICs.X")`), so the C# not yet ported, `MainActivity.cs` and the `*Impl.hx` callers keep working at every commit. `Native.hx` changes from externs into re-exports. A hidden project under the app's name then supplies Avalonia to hxc builds.

**Tech Stack:** Haxe 4.3.7 (`-cs`, `-D no-compilation`), hxc `-D dotnet`, .NET 10, Avalonia 12.1.4, SkiaSharp through Avalonia.Skia, Svg.Skia 5.1.1, utest, hxc's `tests/dotnet` suite.

**Spec:** `docs/superpowers/specs/2026-10-31-haxeui-cs-no-native-design.md`. Read it before any task. Its "What the probes showed" table is the source for how each C# shape is written.

**Layout change (Task 7):** ported classes live in `haxe/ui/backend/cs/native/impl/X.hx`, package `haxe.ui.backend.cs.native.impl`, wherever this plan says `native/X.hx`. A type declared in `Native.hx` has the dotted name `haxe.ui.backend.cs.native.X`, which Haxe 4.3.7 refuses beside a module of that name. Haxe also has no `finally`, so the recipe's `using` is `Scope.get` or `Scope.run` in `net/Net.hx`, or an explicit catch-and-dispose where a closure can't be used (the render thread). `System.Math` resolves against hxcs's .NET 4.5 library, so a member newer than that (`Clamp`) is written by hand.

**Baselines (Task 1, tag `native-baseline`):**
- Suite: 659 assertions, 659 passing, the same with `-D net-ver=45`.
- Small apps: `exit-app`, `early-add`, `window-app` and `clipboard-app` exit 0. `keys-app` builds.
- Gallery: `D:/_github/_haxeui-cs-baseline/gallery/run1` and `run2`, compared with `bench/pixdiff.py` there. Pages that differ between two runs: `page0` and `page4` (both themes), `page1`, `page5` and `tooltip` (light in that pair, so treat both themes as varying). Each differs only in a small box: under 300 pixels, apart from a 60x60 block at (184,160) on `page5` and `tooltip`. On these pages, a later difference outside those boxes is still a bug. `page2` and `page3` must match exactly.
- Timing: **not measured yet, the phone was locked.** `sh D:/_github/_haxeui-cs-baseline/bench/run.sh baseline` times `EpubReader-native-baseline-bench.apk`'s build at any later point, so Task 19 runs it first. EpubReader at 06a6c27. The bench patches a copy of `MainView`, so EpubReader isn't edited, and runs as an app of its own, `...epubreader.csbench`, leaving the reader's position alone. Its first real run is at Task 19.

## Global Constraints

- No `cs.Syntax`, `untyped` or `__cs__` in anything ported. No `#if dotnet` in ported code, unless Task 4's fallback is used, at the one site it names.
- `-D net-ver=45` for every build, in `extraParams.hxml` from Task 1 on.
- Avalonia stays 12.1.4 and Svg.Skia 5.1.1, as `Build.hx` has them. `net10.0`.
- Every class keeps its .NET name and C# member names. Doc comments move over as `/** */`.
- haxeui-cs: every commit goes on master and `haxe tests/headless.hxml` passes at each one, because every HaxeUI C# build on this machine uses this checkout through `haxelib dev`. Nothing is pushed anywhere.
- hxc: work only in a new worktree `D:/_github/_hxc-haxeui-cs`, on a new branch `dotnet-haxeui-cs` cut from `main`. Merge only when Joe says. **Joe may change this; check the plan's header note before Task 2.**
- `$HXC` below means the copy made in Task 2, `D:/_github/_hxc-haxeui-cs/bin/hxc-cs.exe`. Never run an hxc binary another session may be rebuilding.
- For hxc runs, set `HAXE_STD_PATH=C:/HaxeToolkit/haxe/std`.
- haxeui-core-joe is not expected to change. If it has to, commit a `#if cs`-guarded fix straight to its master, as a small commit.
- JoeClash and EpubReader aren't edited. If a build dirties JoeClash's checkout (`ReaderLibSync`), restore nothing and tell Joe.

## Review Focus

1. **Colours with the top alpha bit set** (`0xFF......`), through `UInt`, shifts and `byte` casts: same result as C#'s `uint`, never a negative or sign-extended channel. Pinned in Task 8, `testHighAlphaSurvives`.
2. **A callback throwing a Haxe value, not an exception** (`throw "oops"`), from a frame, timer, or close or back handler: reported, and the app keeps going, on both compilers. Pinned in Task 20, `testHaxeThrowIsReported`.
3. **Astral characters:** an emoji in a Label's HTML and link text. Character handling stays UTF-16 as C#'s did. Pinned in Task 16, `testHtmlKeepsAstralCharacters`.
4. **An hxc build under a path with spaces, or with no network:** `D:\Users\Joe Williamson\...` is real here. It builds and runs, and with no cache and no network it stops with a message saying what was being fetched. Pinned in Task 24's `tests/il-app` checks.
5. **An hxc app started from another working directory:** `dotnet D:/x/App.dll` from `C:\` still finds its resources and native libraries. Pinned in Task 24's `tests/il-app` checks.

---

## The port recipe

Tasks 7 to 23 each follow this. A task only adds what's particular to its file.

**Files for `native/X.cs`:** create `haxe/ui/backend/cs/native/X.hx` with one class or interface per C# type, delete `native/X.cs`. In `Native.hx`, replace each extern for those types with `typedef T = haxe.ui.backend.cs.native.X.T;`. Add externs to `haxe/ui/backend/cs/net/` only for what the file uses.

**Each type** is `@:native("HaxeUICs.T") @:nativeGen class T` (or `interface`), and public, including what C# had `internal`, since C# not yet ported may call it. Its members keep exact .NET signatures, for C# callers:

| C# | Haxe |
|---|---|
| `double`, `int`, `bool`, `string`, `object` | `Float`, `Int`, `Bool`, `String`, `Dynamic` |
| `uint`, `byte`, `float` | `UInt`, `cs.types.UInt8`, `Single` |
| `T[]` | `cs.NativeArray<T>` |
| `Func<T>`, `Action`, `Action<T>` | `cs.system.Func_1<T>`, `cs.system.Action`, `cs.system.Action_1<T>` |
| overloads | `@:overload` on each |
| `get` property with a body | `public var X(get, never):T` with `get_X`, or a plain field when nothing computes it |
| property overriding Avalonia's | `@:protected @:property override function get_X()` |
| `event` handler | a `cs.system.EventHandler_1<T>` local, then `add_E(handler)` |
| routed handler | a local `EventHandler_1<T>`, then `AddHandler(XEvent, cast handler, routes, handled)` |
| `using` | `try { ... } finally x.Dispose();` |
| `foreach` over a .NET list | index it (`implements ArrayAccess<T>` on the extern), or `GetEnumerator` for a true enumerable |
| `A?.B`, `??`, `is T x`, `switch` patterns | explicit `null` checks, `Std.isOfType` then `cast`, plain `if` chains |
| object initialisers | assignments after `new` |
| real `T?` in an Avalonia signature | `cs.system.Nullable_1<T>` |
| `T?` private to the class | `Null<T>` for reference-like use, or a flag beside a struct |

**Traps that compile and then misbehave:**

- `int / int` truncates in C#, while Haxe's `/` gives a `Float`: write `Std.int(a / b)`. `(int)d` is `Std.int(d)`.
- `System.Math.Round` rounds halves to even, and Haxe's `Math.round` doesn't. `Math.Max`, `Min` and `Clamp` differ from Haxe's on NaN. Where the C# named `System.Math`, call `cs.system.Math`.
- `>>` on a `uint` is logical. On a Haxe `Int` it isn't: use `UInt`, or `>>>`.
- `catch (System.Exception e)` becomes `catch (e:Dynamic)`, so a thrown Haxe value is caught too. Report it with `"" + e`.
- `string.StartsWith` and friends are culture-aware unless given a comparison. Keep every comparison the C# had, ordinal where it was ordinal.
- Haxe's C# puts top-level classes in the global namespace, which shadow `System`'s (`Math`, `Array`, `Date`). Externs go through `cs.system.*` or `@:native` full names.
- A hand-written extern must match the real signature. hxc refuses or misbinds one that only happens to compile under C#. `@:overload` is what hxc asks for when more than one .NET overload exists.

**Steps for each file:**

- [ ] Add the task's new test, if it names one, and run `haxe tests/headless.hxml`. It passes against the C# (a test the C# fails means the test is wrong).
- [ ] Port the file, delete the `.cs`, update `Native.hx`.
- [ ] Run `haxe tests/headless.hxml`. Expected: `results: ALL TESTS OK`, with the count from Task 1 plus any added since. `-D test=<case>` runs one case while iterating, but the gate is the whole suite.
- [ ] While the set of ported files is closed (Tasks 7 to 12, and again from Task 21): add a call to `tests/native-il/Main.hx` and run `sh tests/native-il/run.sh`. Expected: `native-il ok`.
- [ ] Commit, with a one-line message saying what moved, in the repo's style (`Deflate and Inflate are Haxe`), ending with the attribution line this session uses.

---

## Part 1: Starting points

### Task 1: Baselines

**Files:**
- Modify: `extraParams.hxml`, `docs/superpowers/plans/2026-10-31-haxeui-cs-no-native.md` (record results under the header)

- [x] **Step 1: Check the trees.** `git -C D:/_github/haxeui-cs status --short` is empty. If not, stop and tell Joe.
- [x] **Step 2: Run the suite.** `haxe tests/headless.hxml`. Record the pass count in this plan's header.
- [x] **Step 3: Add `-D net-ver=45` to `extraParams.hxml`** and rerun. Expected: the same count. If a difference appears, it comes from Haxe's std behaving differently at that version. Stop and tell Joe, since the design assumed this is harmless.
- [x] **Step 4: Small apps.** Run the `build.hxml` of `exit-app`, `early-add`, `window-app`, `keys-app` and `clipboard-app` under `tests/`, as the README describes, and note which pass today.
- [x] **Step 5: Gallery pictures.** Follow the README's gallery section with `tools/gallery/gallery.cs.hxml`, light and `--dark`. Run it twice, and record in this plan's header any page that differs between the two runs: those pages can't be compared pixel for pixel later. Copy `tools/gallery/out` to `D:/_github/_haxeui-cs-baseline/gallery`.
- [x] **Step 6: Keep a baseline APK and timings.** Tag `native-baseline` at this commit (a local tag, never pushed). Ask Joe to connect the phone, build EpubReader's Android app, and record tap-to-drawn for both chapter crossings of *At the Mountains of Madness* (111- and 71-page chapters), using on-device stage timers as the Android performance work did. Commit no temporary logging. Save the APK to `D:/_github/_haxeui-cs-baseline/`. Record the numbers in this plan's header. If the phone isn't available, record that and carry on until Task 19, which needs it.
- [x] **Step 7: Commit** `extraParams.hxml` and this plan.

---

## Part 2: hxc fixes

All in the hxc worktree. Each test is a case in `tests/dotnet/cases.hx.txt` tagged `@gencs`, so its output must match Haxe 4.3.7's, and any new C# goes in `tests/dotnet/netlib/M4Lib/M4Lib.cs`. Hand-written externs in these cases are declared in the case itself, as the existing `netlib-extern-*` cases do. Run with `tests/dotnet/run.sh --compiler $HXC --case <name>`. Commit messages follow hxc's style (`..., for .NET`).

### Task 2: Property override writes a property

**Files:**
- Modify: `src/hxc/codegen/dotnet/TclassToIl.hx` (the property planning near `planVarProperty`, line 740)
- Test: `tests/dotnet/cases.hx.txt`, `tests/dotnet/netlib/M4Lib/M4Lib.cs`

**Interfaces:**
- Produces: `@:protected @:property override function get_X()` in a class extending a hand-written extern writes the override of .NET property `X`.

- [ ] **Step 1: Make the worktree.** `git -C D:/_github/hxc worktree add -b dotnet-haxeui-cs D:/_github/_hxc-haxeui-cs main`, `git submodule update --init --recursive` in it, then `haxelib run aedifex build cpp .`. Copy `bin/cpp/windows/x64/release/bin/hxc.exe` to `bin/hxc-cs.exe`. Repeat the build and copy after each hxc change.
- [ ] **Step 2: Write case `netlib-extern-property-override`.** C#: `public class PropBase { protected virtual string Key => "base"; public string ReadKey() => Key; }` and `public abstract class PropAbstract { protected abstract string Key { get; } public string ReadKey() => Key; }`. Haxe: a hand-written extern for each, with `@:protected private var Key(get, never):String` and `private function get_Key():String`, and a `@:nativeGen` subclass of each overriding `get_Key` to return `"sub"`. `main` prints `ReadKey()` of both. Expected output: `sub`, `sub`.
- [ ] **Step 3: Run it.** Expected: FAIL. Today the first prints `base` and the second can't load.
- [ ] **Step 4: Write the CLR property** matching what Haxe 4.3.7 generates for this: `protected override T X { get { return _get_X(); } }` and `protected virtual T _get_X()`.
- [ ] **Step 5: Run the case, then the whole `tests/dotnet/run.sh` suite.** Expected: PASS, no new failures against hxc's recorded baseline.
- [ ] **Step 6: Commit.**

### Task 3: A class implements a hand-written interface's property

**Files:**
- Modify: `src/hxc/codegen/dotnet/TclassToIl.hx:879-884`
- Test: `tests/dotnet/cases.hx.txt`, `M4Lib.cs`

**Interfaces:**
- Produces: `class C implements HandWrittenInterface` with `@:property public var Bounds(get, never):T` implements the .NET property.

- [ ] **Step 1: Write case `netlib-extern-interface-property`.** C#: `public struct Box { public int W; public Box(int w) { W = w; } }`, `public interface IHasBounds : System.IDisposable, System.IEquatable<IHasBounds> { Box Bounds { get; } }`, and `public static class BoundsReader { public static int Read(IHasBounds b) => b.Bounds.W; }`. Haxe: the extern interface extending `cs.system.IDisposable` and `cs.system.IEquatable_1<IHasBounds>`, and a `@:nativeGen` class implementing it with `Bounds` returning `new Box(33)`. `main` prints `BoundsReader.Read(new C())`. Expected: `33`.
- [ ] **Step 2: Run it.** Expected: FAIL with "a class cannot implement the property Bounds".
- [ ] **Step 3: Implement it.** Only `@:property` vars with `get` are in scope. Keep the refusal, with its message, for an interface var the implementing class doesn't declare with `@:property`.
- [ ] **Step 4: Run the case and the suite.** Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 4: A generic method taking a delegate binds

**Files:**
- Modify: `src/hxc/codegen/dotnet/ExternMembers.hx:384` and the applicability check it reports for
- Test: `tests/dotnet/cases.hx.txt`, `M4Lib.cs`

**Interfaces:**
- Produces: a hand-written `@:overload static function Configure(f:Func_1<App>):B` binds `Configure<TApp>(Func<TApp>)` beside `Configure<TApp>()`, inferring `TApp` from the delegate's type arguments.

- [ ] **Step 1: Write case `netlib-extern-generic-delegate-arg`.** C#: `public static class Gen { public static string Make<T>() where T : new() => "none"; public static string Make<T>(System.Func<T> f) => f().ToString(); }`. Haxe: an extern with one `@:overload` taking `Func_1<Thing>` and a `Thing` whose `ToString` returns `thing`. `main` prints `Gen.Make(fn)`. Expected: `thing`.
- [ ] **Step 2: Run it.** Expected: FAIL with "hxc cannot tell whether the .NET method".
- [ ] **Step 3: Implement it.** Infer a method's type parameters from a generic delegate argument whose type arguments are all known.
- [ ] **Step 4: Run the case and the suite.** Expected: PASS.
- [ ] **Step 5: Commit.**

**Fallback, if this proves large:** skip the fix, and in `Host` alone use `#if dotnet`, finding `Configure` with no parameters through `cs.Lib.toNativeType(AppBuilder).GetMethods()` and calling `MakeGenericMethod(HostApplication).Invoke(null, null)`, which ran in the probe. Tell Joe. It's the one named `#if`.

### Task 5: `Compiler.addNativeLib` works in an init macro

**Files:**
- Modify: `src/hxc/eval/EvalStdLib.hx:3551`, `src/hxc/Compiler.hx:1029` and `:4398`
- Test: `tests/dotnet/cases.hx.txt`

**Interfaces:**
- Produces: `haxe.macro.Compiler.addNativeLib(path)` from `--macro` adds `--net-lib path` under `--cs -D dotnet`, seen by externs at typing and by binding.

- [ ] **Step 1: Write case `netlib-added-by-macro`.** The case's own flags add M4Lib through `--macro haxe.macro.Compiler.addNativeLib("...")` instead of `@netlib`, and call one M4Lib class through a hand-written extern. Expected: same output as the gencs build, if Haxe 4.3.7 also accepts it. If it doesn't under `no-compilation`, drop the `@gencs` tag and note why in the case's comment.
- [ ] **Step 2: Run it.** Expected: FAIL with "does not support native libraries".
- [ ] **Step 3: Implement it.** `registerNativeLibs` must see libraries added after command-line parsing and before typing. Move that call past the init macros, or call it again for the added ones. Don't change the error for targets other than `cs`.
- [ ] **Step 4: Run the case and the suite.** Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 6: The whole suite under hxc against prebuilt C#

The hxc baseline before any file moves.

**Files:**
- Create: `tests/headless-il.hxml`, `tests/il-native/HaxeUICs.csproj`, `tests/run-il.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `sh tests/run-il.sh` builds and runs the suite under `$HXC`, printing the suite's own result line. Later tasks don't use it until Task 24, which replaces its prebuild.

- [ ] **Step 1: Write `tests/il-native/HaxeUICs.csproj`:** `net10.0`, library, `<Compile Include="../../native/*.cs" />`, `HAXEUI_CS_HEADLESS` defined, `AllowUnsafeBlocks`, `CopyLocalLockFileAssemblies=true`, and the package references `Build.hx` uses for a headless app.
- [ ] **Step 2: Write `tests/headless-il.hxml`:** `tests/headless.hxml`'s content minus `-D haxeui_cs_run` and `-cs tests/bin`, plus `--cs tests/bin-il -D dotnet -D unsafe -D dll-name=TestMain`, and `--net-lib` for `HaxeUICs.dll`, `Avalonia.Base.dll`, `Avalonia.Controls.dll` from the prebuild's output.
- [ ] **Step 3: Write `tests/run-il.sh`:** `dotnet build` the csproj, run `$HXC tests/headless-il.hxml`, copy the prebuild's output and native libraries beside `tests/bin-il/TestMain.dll`, and run it with `dotnet`.
- [ ] **Step 4: Run it, and fix what stops it.** Each hxc gap gets a case and a commit in the hxc worktree, as in Tasks 2 to 5. Each wrong extern in `Native.hx` is fixed in haxeui-cs, keeping `haxe tests/headless.hxml` green. **If more than about five independent hxc gaps appear, stop and show Joe the list**, since the design assumed few.
- [ ] **Step 5: Expected: `results: ALL TESTS OK` with Task 1's count.** A test that differs from the Haxe 4.3.7 run is a real difference. Fix its cause in hxc, don't relax the test.
- [ ] **Step 6: Commit** in haxeui-cs.

---

## Part 3: Files outside the cycle

Dependencies measured from `native/`, comments stripped: these depend on no other unported file, so hxc can compile them alone. Each task's list of "Tests" is what covers it in `tests/cases/`.

### Task 7: Scaffolding, with `Deflate` and `Inflate`

**Files:**
- Create: `haxe/ui/backend/cs/native/Deflate.hx`, `Inflate.hx`, `haxe/ui/backend/cs/net/Net.hx`, `tests/native-il/Main.hx`, `tests/native-il/build.hxml`, `tests/native-il/run.sh`
- Delete: `native/Deflate.cs`, `native/Inflate.cs`
- Modify: `haxe/ui/backend/cs/native/Native.hx`, `haxe/ui/backend/cs/macros/Build.hx`, `.gitignore`
- Tests: `TestCompress`

**Interfaces:**
- Consumes: Task 1's `-D net-ver=45`.
- Produces: the recipe's layout. `haxe.ui.backend.cs.net.Net` holds `System.*` externs. Later tasks add `haxe/ui/backend/cs/net/{Avalonia,Controls,Input,Media,Threading,Skia}.hx`, one per area. `tests/native-il/run.sh` compiles `Main.hx` with `$HXC` and runs it, exiting non-zero on a failed check, and last prints `native-il ok`.

- [ ] **Step 1: In `Build.configure`,** before the `dotnet` branch, add `Compiler.include("haxe.ui.backend.cs.native")` and `Compiler.keep("haxe.ui.backend.cs.native")`, both recursive by default. Without them, a Haxe class only C# calls isn't generated, as `HostApplication` won't be for `MainActivity.cs`.
- [ ] **Step 2: Write `tests/native-il/build.hxml`:** `-cp haxe`, `-cp tests/native-il`, `-main Main`, `--cs tests/native-il/bin`, `-D dotnet -D unsafe -D net-ver=45`, `--net-lib` of `Avalonia.Base.dll`, `Avalonia.Controls.dll` and `SkiaSharp.dll` from `tests/bin/bin/Debug/net10.0`. `run.sh` copies that folder's libraries beside the DLL before running.
- [ ] **Step 3: Write `Main.hx`:** a `check(name, ok)` helper, and a Deflate-then-Inflate round trip of 1,000 bytes that must return them unchanged.
- [ ] **Step 4: Port both files by the recipe.** `Run(data, pos, len, level)` keeps its signature, since `NativeCompress` and `NativeUncompress` call it through `Native.hx`. Confirm early that `class X` under `@:native("HaxeUICs.X")` lands in namespace `HaxeUICs`, and that `typedef` re-exports work for `implements`, `extends` and statics. If `implements` through a typedef is refused, point those importers at the real module instead, and say so in this plan's header.
- [ ] **Step 5: Run `haxe tests/headless.hxml` and `sh tests/native-il/run.sh`.** Expected: all pass, `native-il ok`.
- [ ] **Step 6: Commit.**

### Task 8: `ColorMatrix`

**Files:**
- Create: `haxe/ui/backend/cs/native/ColorMatrix.hx`, `haxe/ui/backend/cs/net/Avalonia.hx`, `Media.hx`
- Delete: `native/ColorMatrix.cs`
- Tests: `TestFilters`, new `testHighAlphaSurvives`

**Interfaces:**
- Produces: `ColorMatrix.Apply(m:cs.NativeArray<Single>, argb:UInt):UInt`, an `@:overload` with `Color`, `Compose`, `Brush`, `Filter`, `Forget`, and interface `IColorFiltered`, which C# `UIPainter`, `UIText` and others still implement until ported.

- [ ] **Step 1: Add `testHighAlphaSurvives` to `TestFilters`:** an identity matrix applied to `0xFFFFFFFF`, `0x80FFFFFF` and `0xFF000001` returns each unchanged. A matrix halving alpha applied to `0xFFFFFFFF` returns `0x80FFFFFF` (`Round(127.5)` is 128, to even).
- [ ] **Step 2: Follow the recipe.** The `Filter` cache becomes a hand-written `ConditionalWeakTable` extern with a `Map<String, Bitmap>` value. Its key joins the matrix as C#'s `string.Join(",", m)` does, and only uniqueness matters. Copy pixels with `Marshal.Copy` externs (`IntPtr` to and from `byte[]`). Keep the pixel loop typed, on `cs.NativeArray<UInt8>`. `Channel` uses `cs.system.Math.Round`.
- [ ] **Step 3: Add to `tests/native-il/Main.hx`:** the three identity colours.

### Task 9: `UIFonts`

**Files:** Create `haxe/ui/backend/cs/native/UIFonts.hx`. Delete `native/UIFonts.cs`. Tests: `TestFonts`.

**Interfaces:**
- Consumes: Task 2's property override, for `LoadedFonts.Key`.
- Produces: `UIFonts.FromBytes`, `FromFile`, `Decorations`, `ResolveFamily`, signatures unchanged, as C# callers remain.

- [ ] **Step 1: Follow the recipe.** `LoadedFonts.Add` calls the protected `TryAddGlyphTypeface(stream, out typeface)` with `cs.Out`. The two `Dictionary<string, string>` become Haxe `Map<String, String>`, with a key present holding `null` kept distinct from one absent (`exists`, not a null test), as `_families[full] = null` depends on it.
- [ ] **Step 2: Add to `tests/native-il/Main.hx`:** `ResolveFamily("monospace")` isn't null, and `FromBytes` of non-font bytes returns null.

### Task 10: `PickedFiles`

**Files:** Create `haxe/ui/backend/cs/native/PickedFiles.hx`. Delete `native/PickedFiles.cs`. Tests: `TestPickedFiles`.

**Interfaces:**
- Produces: `Import(dir:String, displayName:String, size:cs.types.Int64, open:cs.system.Func_1<Stream>):String`, with its .NET signature unchanged, as C# `FileDialogs` still passes a lambda. `ImportBytes`, `ImportCut` unchanged.

- [ ] **Step 1: Follow the recipe.** `FailingStream` overrides only `Read(byte[], int, int)`. Haxe can't declare `Span<byte>`.
- [ ] **Step 2: Prove the double still fails.** `testFailedCopyLeavesNothing` must pass *and* `failAfter` must really stop the read. If `Stream.CopyTo` on this class reaches `Read(Span)`, change `Import` to copy with an explicit `Read(byte[], ...)` loop rather than weakening the test.
- [ ] **Step 3: Add to `tests/native-il/Main.hx`:** an `ImportBytes` into a temp folder, then the same with `failAfter` set, which must leave no file under a real name.

### Task 11: `UILayers`

**Files:** Create `haxe/ui/backend/cs/native/UILayers.hx`, `haxe/ui/backend/cs/net/Skia.hx`. Delete `native/UILayers.cs`. Tests: `TestLayers`.

**Interfaces:**
- Consumes: Task 3's interface property, for `Draw.Bounds`.
- Produces: `UILayers`' members, unchanged, for the Haxe code that calls them through `Native.hx`.

- [ ] **Step 1: Follow the recipe, with these three decided routes.** `feature` comes from the public `context.TryGetFeature(cs.Lib.toNativeType(ISkiaSharpApiLeaseFeature))` with a `cast`. `SKImage.FromPixelCopy(info, rgba)` uses the public `byte[]` overload instead of the span, so pass an array of exactly `width * height * 4` bytes, and copy first if `rgba` can be longer. `canvas.Concat(in sk)` is `@:overload function Concat(m:cs.Ref<SKMatrix>)`.
- [ ] **Step 2: Keep `Draw` safe on the render thread.** No `Dynamic`, `trace`, `Std.string`, Haxe `Map` or closures in `Render` and `Paint`. Data is typed fields set before it's handed over, and `Node.Children` is a `cs.NativeArray<Node>` or typed list. `Smooth` is initialised at the class's static setup, not lazily.
- [ ] **Step 3: Add to `tests/native-il/Main.hx`:** a `Draw` constructed and its `Bounds` read through the interface.

### Task 12: `UITextInput`

**Files:** Create `haxe/ui/backend/cs/native/UITextInput.hx`, `haxe/ui/backend/cs/net/Controls.hx`, `Input.hx`. Delete `native/UITextInput.cs`. Tests: `TestTextInput`.

**Interfaces:**
- Consumes: Task 2's override, for `StyleKeyOverride`. Task 8's `IColorFiltered`, Task 9's `UIFonts`.
- Produces: `UITextInput`, interface `ITextInputListener`, members unchanged.

- [ ] **Step 1: Follow the recipe.** `e.NameScope.Find<ScrollViewer>(name)` is `INameScope.Find(name)` with a `cast`. `TranslatePoint` returns `cs.system.Nullable_1<Point>`, and `?? default` becomes a `HasValue` check. `context.PushClip` is `try`/`finally`.
- [ ] **Step 2: Check its look.** `TestTextInput` must fail if `StyleKeyOverride` is removed: comment it out, run, confirm the failure, restore it. If nothing fails, add `testHasTextBoxTemplate`, asserting that `PART_ScrollViewer` was found after a layout pass, and keep it.
- [ ] **Step 3: Add to `tests/native-il/Main.hx`:** only that the module compiles, as a control needs a running app.

---

## Part 4: The cycle

`Host`, `UIPanel`, `UIStyle`, `UIImage`, `UIGraphics`, `UIText`, `UIEvents`, `UIClipboard`. These refer to each other, so hxc can't compile any alone. The gate here is `haxe tests/headless.hxml` only, per the spec's "The gate during the port". C# and generated C# are one assembly under Haxe 4.3.7, so one file at a time still works.

### Task 13: `UIImage`

**Files:** Create `haxe/ui/backend/cs/native/UIImage.hx`. Delete `native/UIImage.cs`. Tests: `TestImages`, `TestSvgPalette`.

**Interfaces:** Produces `UIImage` and `UIImageView`, members unchanged. Palette statics stay on `UIImage`.

- [ ] **Step 1: Follow the recipe.** Svg.Skia externs go in `net/Skia.hx`. `Marshal.Copy` with `buffer.Address + row * buffer.RowBytes` needs `IntPtr.Add`. `UIImageView.Render` is a public override.

### Task 14: `UIStyle`

**Files:** Create `haxe/ui/backend/cs/native/UIStyle.hx`. Delete `native/UIStyle.cs`. Tests: `TestStyles`, `TestCursors`.

**Interfaces:** Produces `UIStyle`, its public fields and `CursorFor(css)`. `StyleMapper.toNative` keeps assigning them.

- [ ] **Step 1: Follow the recipe.** The cursor table is a `static var` `Map<String, StandardCursorType>`. `Shadows = default` is `new BoxShadows()`, on an `@:struct` extern.

### Task 15: `UIGraphics`

**Files:** Create `haxe/ui/backend/cs/native/UIGraphics.hx`. Delete `native/UIGraphics.cs`. Tests: `TestGraphics`.

**Interfaces:** Produces `UIGraphics`, its drawing commands and `Changed`, which `UIPainter` (C# until Task 19) sets to `_painter.InvalidateVisual`, so `Changed` stays a `cs.system.Action`.

- [ ] **Step 1: Follow the recipe.** `Op` becomes `enum abstract Op(Int)`. `struct Command` becomes a plain `@:nativeGen` class, as the list holds references. Check the replay isn't slower with Task 19's timing. `Marshal.WriteByte` takes an `IntPtr`, with `IntPtr.Add` for the offsets.

### Task 16: `UIText`

**Files:** Create `haxe/ui/backend/cs/native/UIText.hx`. Delete `native/UIText.cs`. Tests: `TestText`, new `testHtmlKeepsAstralCharacters`.

**Interfaces:** Produces `UIText`, including `LinkCount` and `LinkAt(x, y)`, which `UIPanel` calls.

- [ ] **Step 1: Add `testHtmlKeepsAstralCharacters` to `TestText`:** a Label whose HTML is `<a href="x">a😀b</a> é` has plain text `a😀b é`, and one link, whose range covers the emoji's two UTF-16 units. The width of `a😀b` is greater than that of `ab`.
- [ ] **Step 2: Follow the recipe.** `RunStyle.Color` and `Size` are `Null<UInt>` and `Null<Float>`, private to the class. The HTML reader indexes `String` by UTF-16 unit, as C# did: use `charCodeAt`, never anything `haxe.Utf8`-based. `OnPropertyChanged` and `OnAttachedToVisualTree` are `@:protected` overrides. The measuring cache keeps working: `TextLayout` is disposed in a `finally`.

### Task 17: `UIEvents`

**Files:** Create `haxe/ui/backend/cs/native/UIEvents.hx`. Delete `native/UIEvents.cs`. Tests: `TestMouse`, `TestKeys`, `TestTouchTooltips`.

**Interfaces:** Produces `EventKind` (the `const int`s as `public static inline var`), `IPanelListener`, `NativeEvents.Cancel`, `ClickState`, `EventRouter(target, handledEventsToo)`, `Update(kinds, listener)`, `SuppressNextClick()`, `KeyCodes`.

- [ ] **Step 1: Follow the recipe.** About 12 routed handlers: `Attach` makes one `EventHandler_1<...>` per kind, as locals with explicit parameter types, then `AddHandler(InputElement.XEvent, cast handler, routes, handled)`, with the `*Event` statics typed as `RoutedEventBase`. `RoutingStrategies.Bubble | Direct` is a flags value: a named constant `(cast 5 : RoutingStrategies)`, Direct being 1 and Bubble 4 (read them from the assembly to confirm). If a compiler refuses that cast, use `cs.Flags`. `NativeEvents.Cancel` keeps testing `ClickState` first.
- [ ] **Step 2: Check the hot path.** `Pointer` must not allocate per move beyond what the C# did. Handlers are made once, in `Attach`.

### Task 18: `UIClipboard`

**Files:** Create `haxe/ui/backend/cs/native/UIClipboard.hx`, `haxe/ui/backend/cs/net/Threading.hx`. Delete `native/UIClipboard.cs`. Tests: `TestClipboard`, and `tests/clipboard-app`.

**Interfaces:** Produces `SetText`, `GetText`, `Clear`, `Flush`, `Wait(task)`, and `SensitiveFormats`, which `TestDriver` (C# until Task 23) reads.

- [ ] **Step 1: Follow the recipe.** `Task` and `Task<T>` are hand-written externs in `net/Net.hx`, `Task` and `Task_1<T>` under `@:native("System.Threading.Tasks.Task")`, as the probe's was. `formats.Result.Contains(...)` is a plain loop, as it's LINQ. `Wait` keeps the nested `DispatcherFrame`, with `ContinueWith(Action_1<Task>, TaskScheduler.Default)`, and `TickCount64` is `Int64`. `new byte[4]` is `new cs.NativeArray<UInt8>(4)`. `TryGetTextAsync` is a static call on `ClipboardExtensions`.
- [ ] **Step 2: Run `haxe tests/clipboard-app/build.hxml`** with `-D haxeui_cs_run`, as the README describes. Expected: as in Task 1, since `Win32Clipboard.cs` stays through `addNative` under Haxe 4.3.7.

### Task 19: `UIPanel`, and the midway timing

**Files:** Create `haxe/ui/backend/cs/native/UIPanel.hx`. Delete `native/UIPanel.cs`. Tests: `TestPanelTransform`, `TestBridge`, `TestLayout`, `TestFilters`, `TestDirectives`.

**Interfaces:** Produces `UIPanel` and `UIPainter`, all members `Native.hx` lists.

- [ ] **Step 1: Follow the recipe.** `class UIPanel extends Canvas implements ICustomHitTest`. Private `Rect?` is `hasRect:Bool` beside the `Rect`. `DrawTiled`'s `Size? tile` becomes a `Size` and a `Bool`. `AddHandler`'s lambdas for links are made once, in `LinksChanged`. `SequenceEqual` is a plain loop. `Panel.Render` is sealed, so `UIPainter` stays a child, as its comment says.
- [ ] **Step 2: Run the suite.** Expected: as the recipe.
- [ ] **Step 3: Gallery check.** Build the gallery and compare against `D:/_github/_haxeui-cs-baseline/gallery`, pixel for pixel, with a small script in the scratchpad. Any difference, on a page Task 1 didn't record as varying, is a bug to fix now.
- [ ] **Step 4: Midway timing. Ask Joe to connect the phone.** Build EpubReader's Android app from this commit, and time the same two chapter crossings as Task 1. Confirm the two APKs differ. More than 10% slower stops the port for a tuning pass. If tuning can't bring it back, stop and show Joe the numbers. Otherwise record the numbers in this plan's header.
- [ ] **Step 5: Commit.**

### Task 20: `Host`

**Files:** Create `haxe/ui/backend/cs/native/Host.hx`. Delete `native/Host.cs`. Modify `templates/android/MainActivity.cs` only if a name had to change (it shouldn't). Tests: `TestApp`, `TestLifecycle`, `TestScale`, `TestEventLoop`, `TestDensity`, new `testHaxeThrowIsReported`; `tests/exit-app`, `early-add`, `window-app`, `keys-app`.

**Interfaces:**
- Consumes: Task 4's fix.
- Produces: `HostApplication` and `Host`, with everything `Native.hx` lists. `Host.Entry`, `LeaveApp`, `FinishApp` are public statics of type `cs.system.Action`, `FilesDir` a `String`, assignable from `MainActivity.cs`.

- [ ] **Step 1: Add `testHaxeThrowIsReported` to `TestLifecycle`:** a `nextFrame` callback that does `throw "oops"`, with a second callback in the same frame, which must still run. A close handler that throws `"oops"` makes `AskClose()` return `true`. A back handler that throws makes `RaiseBack()` return `false`.
- [ ] **Step 2: Follow the recipe.**
  - `#if HAXEUI_CS_HEADLESS` is `#if haxeui_cs_headless`, and `#if ANDROID` is `#if haxeui_cs_android`. The Avalonia.Android and Android.App externs live behind that define.
  - Start Avalonia with `AppBuilder.Configure(factory)`, where `factory:Func_1<HostApplication>` returns `new HostApplication()`. It's `@:overload`, and needs Task 4 under hxc.
  - `StartWithClassicDesktopLifetime`, `UsePlatformDetect`, `UseSkia` and `UseHeadless` are static calls on their extension classes.
  - `HostApplication` overrides `Initialize` and `OnFrameworkInitializationCompleted`. `ApplicationLifetime is X` is `Std.isOfType` then `cast`.
  - `window.PropertyChanged` compares `e.Property` by reference to `TopLevel.ClientSizeProperty`, through a static extern typed as the base `AvaloniaProperty`.
  - `_frameQueue` is a Haxe `Array<ICallback>`. Timers use `EventHandler` delegates (`cs.system.EventHandler`) from `DispatcherTimer`'s constructor, with `TimeSpan.FromMilliseconds`.
- [ ] **Step 3: Check statics on Android's path.** `AndroidApp.OnCreate` sets `Host.FilesDir` and `Host.Entry` before `cs.Boot.init()` runs. Confirm in the generated `Host.cs` that this assignment doesn't depend on anything `Boot.init` sets. Build and start `tests/android-app` on the emulator (`Medium_Phone_API_36.1`), per the README, and confirm `adb logcat` has no `FATAL EXCEPTION` and the app draws. If it depends on `Boot.init`, make those statics plain fields with no initialiser.
- [ ] **Step 4: Run the suite and the small apps from Task 1.** Expected: same as Task 1.
- [ ] **Step 5: Commit.**

### Task 21: The cycle closes: hxc compiles it

**Files:** Modify `tests/native-il/Main.hx`, `tests/native-il/build.hxml`.

- [ ] **Step 1: Add everything now ported to `Main.hx`,** which no longer needs the C# prebuild for those classes. Start Avalonia headless, as the probe did, make a `UIPanel` with a `UIText`, an image and a `UIGraphics` rectangle in a window, capture it with `CaptureRenderedFrame`, and check one pixel's colour.
- [ ] **Step 2: Run `sh tests/native-il/run.sh`.** Expected: `native-il ok`. Every hxc gap gets a case and a commit, as in Task 6. The same stop rule applies: more than about five independent gaps, stop and show Joe.
- [ ] **Step 3: Commit.**

---

## Part 5: The rest

### Task 22: `FileDialogs`

**Files:** Create `haxe/ui/backend/cs/native/FileDialogs.hx`, `haxe/ui/backend/cs/native/Continue.hx`. Delete `native/FileDialogs.cs`. Tests: `TestDialogs`, new `tests/cases/TestContinue.hx`. Modify `tests/TestMain.hx` (register it).

**Interfaces:**
- Consumes: Task 10's `PickedFiles.Import`, Task 20's `Host.TopLevel`.
- Produces: `Continue.then<T>(task:Task_1<T>, done:T->Void, failed:Dynamic->Void):Void`, and `Continue.thenVoid(task:Task, done:Void->Void, failed:Dynamic->Void):Void`. Each runs its callback on the UI thread, after the task, exactly once, and `failed` gets the task's inner exception.

- [ ] **Step 1: Write `TestContinue`,** with tasks from a `TaskCompletionSource_1<String>` extern, so the test decides when each finishes: `testDoneGetsTheResult` (`SetResult("x")`), `testFailedGetsTheException` (`SetException` with a message, `failed` sees that message and `done` never runs), `testRunsOnTheUiThread` (`SetResult` from a `Thread`, and the callback's `Thread.CurrentThread` equals the UI thread's), `testNothingEscapes` (`done` throwing `"oops"` is reported and doesn't reach the dispatcher).
- [ ] **Step 2: Run it.** Expected: FAIL, `Continue` not found.
- [ ] **Step 3: Implement `Continue`** with `ContinueWith` and `Dispatcher.UIThread.Post`, so it matches `await`'s return to the UI thread without depending on a synchronization context. `AggregateException` is unwrapped to its first inner exception, as `await` does.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Port `FileDialogs` by the recipe.** Each `async void` becomes a chain through `Continue`, with every step wrapped so that nothing thrown reaches the dispatcher, keeping the C#'s `Report`, `Cancel`, `Fail` and `Answer`. `OpenOnAndroid` runs `PickedFiles.Import` through `Task.Run(Func_1<String>)` off the UI thread. `file.OpenReadAsync().GetAwaiter().GetResult()` becomes `.Result`, and `AggregateException` is handled as `Continue` does. `properties?.Size is ulong known` reads a `cs.system.Nullable_1<UInt64>`.
- [ ] **Step 6: Real pickers, by hand.** In a real window, `tests/window-app` or a scratch app, ask Joe to open a file, cancel a file dialog, save a file and pick a folder, and report the paths. In the emulator, pick a document through `tests/android-app`. Expected: each answers as before, and cancel calls `OnCancelled`.
- [ ] **Step 7: Commit.**

### Task 23: `TestDriver`, and the last `.cs`

**Files:** Create `haxe/ui/backend/cs/native/TestDriver.hx`. Delete `native/TestDriver.cs` and the `native/` folder. Modify `haxe/ui/backend/cs/macros/Build.hx`. Tests: everything.

**Interfaces:** Produces `HeadlessDriver`, members unchanged. `haxe.ui.backend.cs.TestDriver` keeps calling it.

- [ ] **Step 1: Port by the recipe.** The module's content is inside `#if haxeui_cs_headless`. `Enum.TryParse<PhysicalKey>` becomes `cs.system.Enum.Parse(Type, name)` with a `catch`. `Marshal.ReadInt32` gives a signed `Int`: cast to `UInt` before `ToArgb`. The HTTP server is one `cs.system.threading.Thread` around a blocking `AcceptTcpClient`, starting a new thread for each client, with `Thread.Sleep(delayMs)`. Set `IsBackground = true` so an unstopped server doesn't hold the process, and `Stop()` ends the accept with an exception, which ends the thread.
- [ ] **Step 2: In `Build.hx`,** `nativeItems` lists only the app's own (`appNatives`). Remove the headless exclusion, the `HAXEUI_CS_HEADLESS` define from `buildProject`, and the comment about `native/*.cs`. In `templates/AndroidApp.csproj`, `::NATIVE_DIR::` stays for the app's own.
- [ ] **Step 3: Check no project compiles leftovers.** `haxe tests/exit-app/build.hxml -D haxeui_cs_no_dotnet`, then search the `.csproj` for `native`. Expected: no match.
- [ ] **Step 4: Run the suite.** Expected: as the recipe.
- [ ] **Step 5: Commit.**

---

## Part 6: hxc without a project

### Task 24: Avalonia for hxc builds, and the full suite under hxc

**Files:**
- Create: `haxe/ui/backend/cs/macros/IlLibraries.hx`, `templates/IlLibraries.csproj`, `tests/il-app/App.hx`, `tests/il-app/build.hxml`, `tests/il-app/check.sh`
- Modify: `haxe/ui/backend/cs/macros/Build.hx` (`configureIl`), `tests/headless-il.hxml`, `tests/run-il.sh`, `tests/native-il/` (delete), `tests/il-native/` (delete)

**Interfaces:**
- Consumes: Task 5's `Compiler.addNativeLib`.
- Produces: `IlLibraries.prepare(appName:String, headless:Bool):Void`, called from `configureIl`. It makes the cached output if needed and adds a `--net-lib` for each managed DLL. `IlLibraries.install(outDir:String):Void`, from `Context.onAfterGenerate`, copies that output into `outDir` and overwrites `App.dll` and `App.runtimeconfig.json` with hxc's.
- App name: `-D dll-name` when given, otherwise `configureIl` defines it as the main class's name, so an hxc app is `<Main>.dll`, as a C# build's is.
- Cache key: app name, headless or not, every package and version. Location: `<haxelib root>/.cache/il/<key>/`, in `.gitignore`.

- [ ] **Step 1: Write `tests/il-app/check.sh`,** running a small app (one Label, prints `ready`, exits) through these, each asserting its expected result:
  - built into `tests/il-app/bin with space/`, run with `dotnet "<path>/App.dll"`: prints `ready`
  - run from `C:\` with a full path to the DLL: prints `ready`, and a Haxe resource it embeds loads
  - run through `App.exe` on Windows: prints `ready`
  - run on WSL, same folder: prints `ready`
  - with the cache emptied, `NUGET_PACKAGES` and `NUGET_HTTP_CACHE_PATH` pointed at empty folders, and `RestoreSources=http://127.0.0.1:9/` in the environment (MSBuild reads it as a property): the build fails with a message naming `haxeui-cs` and "fetching Avalonia"
- [ ] **Step 2: Run it.** Expected: FAIL, since `--net-lib` isn't supplied.
- [ ] **Step 3: Write `templates/IlLibraries.csproj`:** same packages as `buildProject`, `AssemblyName` set to the app's name, `OutputType` by today's rule, an empty `Main` as a generated `.cs`, generated in the cache folder and never in the app's folders.
- [ ] **Step 4: Implement `IlLibraries`** and call it from `configureIl`. A failed `dotnet build` is a `Context.fatalError` saying what was being fetched, with `dotnet`'s output included. Pass `--net-lib` for `Avalonia.Base`, `Avalonia.Controls`, `Avalonia.Headless` when headless, `Avalonia.Skia`, `Avalonia.Desktop`, `Avalonia.Themes.Simple`, `SkiaSharp`, `Svg.Skia` and anything else externs name. `haxeui_cs_android`, `haxeui_cs_publish` and `haxeui_cs_run` stay refused. If `Context.onAfterGenerate` doesn't fire under hxc's `-D dotnet`, that's an hxc gap for a case and a fix, as in Task 6.
- [ ] **Step 5: Run `check.sh`.** Expected: all pass.
- [ ] **Step 6: Reduce `tests/headless-il.hxml`** to the suite with no `--net-lib`, and `tests/run-il.sh` to compile and run. Delete `tests/il-native/` and `tests/native-il/`.
- [ ] **Step 7: Run `sh tests/run-il.sh`.** Expected: `results: ALL TESTS OK` with the same count as `haxe tests/headless.hxml`. A difference between the two is a bug, in hxc or the port, not to be accepted.
- [ ] **Step 8: Commit.**

### Task 25: No C# left behind, and the README

**Files:**
- Modify: `haxe/ui/backend/PlatformImpl.hx`, `haxe/ui/backend/cs/macros/OrdinalStringTools.hx`, `README.md`, `haxelib.json` if it lists `native`
- Create: `tests/check-no-native.sh`

**Interfaces:**
- Produces: `sh tests/check-no-native.sh` exits non-zero if `native/` exists, or if `cs.Syntax`, `untyped` or `__cs__` appears under `haxe/`, or `.cs` appears in the library anywhere but `templates/android/MainActivity.cs`. The `tests/clipboard-app/Win32Clipboard.cs` helper is outside `haxe/` and stays, by the spec's non-goals.

- [ ] **Step 1: Write the script and run it.** Expected: FAIL on the two `cs.Syntax` files.
- [ ] **Step 2: Replace `cs.Syntax.code`.** `PlatformImpl.getSystemLocale` uses a `CultureInfo` extern. `OrdinalStringTools` builds macro calls to `StartsWith(other, StringComparison.Ordinal)` through a `cast` to `cs.system.String`. `TestStd` already covers `startsWith` and `endsWith`.
- [ ] **Step 3: Run the script, `haxe tests/headless.hxml` and `sh tests/run-il.sh`.** Expected: all pass.
- [ ] **Step 4: Update `README.md`.** "How it fits together" says `haxe/ui/backend/cs/native/*.hx` is everything Avalonia and knows nothing of HaxeUI. Replace the `-D dotnet` paragraph's two-stage text with: `hxc app.hxml` needs the .NET SDK, and leaves a folder to run with `dotnet App.dll` or `App.exe`, which a hidden project supplies Avalonia to; `addPackage`, `addNative`, `haxeui_cs_run`, `haxeui_cs_publish` and `haxeui_cs_android` are as they are there. Add `-D net-ver=45` only where an app's `.hxml` is shown, if needed.
- [ ] **Step 5: Commit.**

### Task 26: End-of-port checks

No new code unless a check fails. Each failure becomes a fix with a test, then this task resumes.

**Files:** Modify this plan (results under the header).

- [ ] **Step 1: Windows, both compilers.** `haxe tests/headless.hxml` and `sh tests/run-il.sh`: same count. All small apps from Task 1, both compilers where they don't need `addNative`.
- [ ] **Step 2: Linux, hxc's Windows-built folders, under WSL.** The headless suite, then `exit-app`, `early-add`, `window-app` in a real window, with `LD_LIBRARY_PATH` to `~/avalonia-libs` and `~/.dotnet10/dotnet`. Expected: as the README's Linux section records for today.
- [ ] **Step 3: Gallery.** Build under both compilers, light and `--dark`. Expected: pixel-identical to `D:/_github/_haxeui-cs-baseline/gallery` and to each other, apart from pages Task 1 recorded as varying. Then `python -I tools/gallery/compare.py` as usual.
- [ ] **Step 4: Android.** `tests/android-app` and EpubReader build and start, on the emulator and the phone, and `arm64` packages. Back, pause and a picked document work as in the Android plan's check script.
- [ ] **Step 5: Final timing. Ask Joe to connect the phone.** Same as Task 19 Step 4, against the baseline APK. More than 10% slower: tuning pass, then Joe. Report the numbers either way.
- [ ] **Step 6: JoeClash.** Its Joeditor gate still passes: `haxe tools.joeditor.cs.hxml`, then `--cs-accept`, per its own docs, in a separate worktree, as the commit policy says.
- [ ] **Step 7: Report to Joe.** The hxc branch waiting to be merged, the Mac check still open from the earlier plan, and the numbers from Step 5.
