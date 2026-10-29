# haxeui-cs Android Target Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `-D haxeui_cs_android` builds any haxeui-cs app into an Android APK with no app changes, and EpubReader runs on the emulator with everything its heaps-android build does.

**Architecture:** Android is a define inside haxeui-cs. The build macro writes a `net10.0-android` project and a generated `MainActivity` that starts Avalonia in single-view mode, sets the working directory to the app's files dir, then calls the Haxe entry point once per process. `Host` stops depending on a desktop `Window`. Android-only behaviour (picked-file import, back, pause, long-press tooltips, immersive) is built as small units that are tested headlessly where they don't need a device, and on the emulator where they do.

**Tech Stack:** Haxe 4.3 (C# target), .NET 10 + `android` workload, Avalonia 12.1.4 (`Avalonia.Android`), utest headless suite, adb + emulator `Medium_Phone_API_36.1` (x86_64).

**Spec:** `docs/superpowers/specs/2026-10-29-haxeui-cs-android-design.md` (haxeui-cs repo). Read it before any task.

## Global Constraints

- Desktop builds unchanged: a desktop `.csproj` is byte-for-byte what it was before this work, and `haxe tests/headless.hxml`, `exit-app`, `early-add`, `window-app`, `clipboard-app` pass as before.
- App code unchanged except EpubReader's one pause hook (Task 7).
- Trimming off in every Android build (`PublishTrimmed=false`, `AndroidLinkMode=None`).
- Defines: `haxeui_cs_android`, `haxeui_cs_android_id=<id>` (required), `haxeui_cs_android_label=<label>` (required), `haxeui_cs_android_abi=arm64-v8a|x86_64` (default `arm64-v8a`).
- EpubReader: id `com.joewilliamson.epubreader.cs`, label `Reader (C#)`, output `bin/cs-android`.
- Every check runs on the x86_64 emulator; arm64 must build and package only.
- Native C# writes `System.Math`, `System.Array` etc. (Haxe's global-namespace classes shadow them), and `global::` for Haxe types.
- C# that only Android has goes behind `#if ANDROID` (the SDK defines it for `net10.0-android`); Haxe-side behind `#if haxeui_cs_android`.
- Never write to the desktop `state.json` when probing EpubReader (memory: probe runs use a scratch state file).

## Review Focus

1. **Rotating mid-book:** a resize and reflow, never a second `main` or a lost place. Pinned in Task 6's check script (rotation step, `main ran 1`).
2. **Back with nothing open, then relaunch:** the same process resumes and `main` does not run again. Pinned in Task 6's check script.
3. **Killed in the background, relaunched:** `main` runs again in the files dir and finds what it wrote before. Pinned in Task 6's check script (`am kill` step).
4. **Picker read fails halfway** (provider error, cloud file offline): no partial file left under a real name, and an error rather than a crash. Pinned in Task 2 (`testFailedCopyLeavesNothing`) and Task 6b (message box).
5. **Display names a filesystem can't take** (a slash, empty, `..`) and the same book picked twice: sanitised, and the earlier copy reused. Pinned in Task 2.

---

### Task 1: Preconditions and toolchain smoke build

Decides how every later Android check is run.

**Files:** none in the repos. Scratch project under the session scratchpad.

- [ ] **Step 1: Check the starting trees.** `git -C D:/_github/haxeui-cs status --short` and `git -C D:/_github/EpubReader status --short` must both be empty (the spec waits for the clipboard work and the `build.cs.hxml` change to be committed). If either isn't, stop and tell Joe.
- [ ] **Step 2: Snapshot the desktop projects.** Run `haxe tests/exit-app/build.hxml -D haxeui_cs_no_dotnet` and `haxe tests/headless.hxml -D haxeui_cs_no_dotnet` in haxeui-cs. Copy `tests/exit-app/bin/Main.csproj` and `tests/bin/TestMain.csproj` to `<scratch>/baseline/`. Task 5 diffs against them.
- [ ] **Step 3: Build a minimal Avalonia Android app from the agent shell.** In `<scratch>/smoke/`, create a `net10.0-android` csproj with `Avalonia.Android` 12.1.4, `ApplicationId=com.example.smoke`, `RuntimeIdentifier=android-x64`, `EmbedAssembliesIntoApk=true`, and an `AvaloniaMainActivity<App>` whose `App` sets a `TextBlock` as the single view. Run `dotnet build -c Debug`.
  Expected: `bin/Debug/net10.0-android/android-x64/com.example.smoke-Signed.apk` exists.
- [ ] **Step 4: Install and run on the emulator.** Start it with `"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd Medium_Phone_API_36.1 -no-snapshot-save` (in the background), then `adb wait-for-device`, `adb install -r <apk>`, `adb shell monkey -p com.example.smoke -c android.intent.category.LAUNCHER 1`, wait 5 s, then `adb exec-out screencap -p > smoke.png`.
  Expected: the PNG shows the text, and `adb logcat -d | grep -E "FATAL EXCEPTION"` is empty.
- [ ] **Step 5: Record the outcome** at the top of this plan, under the header, as `Verification mode: agent` (steps 3–4 passed) or `Verification mode: Joe` (javac/d8/gradle failed in the agent shell, with the error). In `Joe` mode, every later emulator step becomes a checklist handed to Joe at the end of its task, and the task is not marked done until he reports back.

---

### Task 2: Picked-file import (`PickedFiles`)

heaps-android's import rules, as a pure C# unit that is tested headlessly on Windows.

**Files:**
- Create: `native/PickedFiles.cs`
- Modify: `haxe/ui/backend/cs/native/Native.hx` (extern)
- Create: `tests/cases/TestPickedFiles.hx`. Modify: `tests/TestMain.hx` (register the case)

**Interfaces:**
- Produces (C#, namespace `HaxeUICs`):
  - `public static class PickedFiles`
  - `public static string Import(string dir, string displayName, long size, System.Func<System.IO.Stream> open)`: returns the absolute path of the copy. Throws `System.IO.IOException` on failure, leaving neither the destination nor its `.part` behind. `size < 0` means unknown.
  - `public static string ImportBytes(string dir, string displayName, byte[] bytes, bool knownSize, int failAfter)`: a test and helper entry. It wraps `bytes` in a stream that throws `IOException` after `failAfter` bytes (`-1`: never).
- Produces (Haxe extern in `Native.hx`): `extern class PickedFiles { static function ImportBytes(dir:String, displayName:String, bytes:haxe.io.BytesData, knownSize:Bool, failAfter:Int):String; }`

Rules (from heaps-android `MainActivity.kt` `importDocument`/`sanitiseName`/`candidateFile`):
- **Name:** trim it, and replace `/` and `\` with `_`. If it is then empty, `.` or `..`, use `picked-<unix ms>`.
- **Candidates:** `name`, then `base (2).ext`, `base (3).ext`, … The extension is from the last `.`, and only if that `.` isn't the first character.
- **Walk:** go through the candidates. Reuse the first existing file whose length equals `size`. When `size < 0`, never reuse. Otherwise copy into the first candidate that doesn't exist yet.
- **Copy:** write to `<dest>.part`, then rename it to `<dest>`. `dir` is created if missing.

- [ ] **Step 1: Write the failing tests** in `TestPickedFiles`. Each test uses a fresh `tests/bin/picked-<test>/` dir, deleted first.
  - `testImportsUnderDisplayName`: `"Book.epub"`, bytes `"abc"`. The returned path normalises to `<dir>/Book.epub`, and its content is `"abc"`.
  - `testSameBookTwiceReusesCopy`: import `"abc"` twice. Both return the same path, and the dir holds 1 file.
  - `testDifferentBookSameNameGetsSuffix`: `"abc"` then `"abcd"`. The second returns `<dir>/Book (2).epub`.
  - `testWalksPastSuffixes`: `"abc"`, `"abcd"`, `"abcd"`, `"abcde"`. The 2nd and 3rd return the same path, and the 4th returns `Book (3).epub`.
  - `testUnknownSizeAlwaysFreshSlot`: `"abc"` twice with `knownSize=false`. Returns `Book.epub` then `Book (2).epub`.
  - `testNoExtension`: `"README"` twice with different bytes. Returns `README` then `README (2)`. `".hidden"` twice gives `.hidden (2)`.
  - `testSeparatorsAndEmptyNames`: `" a/b\\c.epub "` gives `a_b_c.epub`. `""`, `"."` and `".."` each give a name starting with `picked-`.
  - `testFailedCopyLeavesNothing`: `failAfter=2` on `"abcdef"` throws (wrap the call in `try`/`catch` and `Assert.isTrue(threw)`), and afterwards the dir is empty.
- [ ] **Step 2: Run them to see them fail.** Run: `haxe tests/headless.hxml -D test=TestPickedFiles`. Expected: compile error, `PickedFiles` unknown.
- [ ] **Step 3: Implement `native/PickedFiles.cs`** to the rules above. Add the extern.
- [ ] **Step 4: Run them to see them pass.** Run: `haxe tests/headless.hxml -D test=TestPickedFiles`. Expected: all 8 pass. Then run `haxe tests/headless.hxml`: the whole suite passes.
- [ ] **Step 5: Commit.** `git add native/PickedFiles.cs haxe/ui/backend/cs/native/Native.hx tests/cases/TestPickedFiles.hx tests/TestMain.hx`, then `git commit -m "PickedFiles: heaps-android's import rules for a picked document"`

---

### Task 3: Back and pause, as app-facing APIs

Host-agnostic Haxe APIs with C# raise points. Tested headlessly by raising them from C#.

**Files:**
- Create: `haxe/ui/backend/cs/BackButton.hx`, `haxe/ui/backend/cs/AppLifecycle.hx`
- Modify: `native/Host.cs`, `haxe/ui/backend/cs/native/Native.hx`
- Create: `tests/cases/TestLifecycle.hx`. Modify: `tests/TestMain.hx`

**Interfaces:**
- Produces (C# `Host`):
  - `public interface IBackListener { bool OnBack(); }` and `public interface IPauseListener { void OnPause(); }` (next to `ICloseListener`)
  - `public static IBackListener BackListener { get; set; }` and `public static IPauseListener PauseListener { get; set; }`
  - `public static bool RaiseBack()`: asks `BackListener`. Returns false when it is null, or when it threw (the throw is reported to stderr with `haxeui-cs: a back handler threw: `).
  - `public static void RaisePause()`: calls `PauseListener` if set. A throw is reported (`haxeui-cs: a pause handler threw: `) and swallowed. Then `WakeEventsPump()`.
- Produces (Haxe):
  - `haxe.ui.backend.cs.BackButton`: `static function addListener(fn:Void->Bool):Void`, `removeListener(fn)`, `clearListeners()`. Listeners are asked newest first, the first `true` wins, and a listener may remove itself while being asked (iterate a copy). Registering the first listener sets `Host.BackListener`. This is the same shape as heaps-android's `BackButton`. Unlike heaps-android, there is no `onUnhandled`: unhandled back is the host's job (Task 6b).
  - `haxe.ui.backend.cs.AppLifecycle`: `static var onPause(default, set):Null<Void->Void>`, with the setter wiring `Host.PauseListener`. This is the same pattern as `WindowClose.onRequest`.

- [ ] **Step 1: Write the failing tests** in `TestLifecycle`. `teardown` calls `BackButton.clearListeners()` and sets `AppLifecycle.onPause = null`.
  - `testNoListenersIsUnhandled`: `Assert.isFalse(Host.RaiseBack())`.
  - `testNewestListenerFirst`: add `a` (logs "a", returns false) and then `b` (logs "b", returns true). `RaiseBack()` is true and the log is `["b"]`.
  - `testFallsThroughToOlder`: `a` returns true and `b` returns false. True, with log `["b","a"]`.
  - `testListenerMayRemoveItself`: a listener that removes itself and returns true. The first raise is true, the second is false.
  - `testThrowingListenerIsUnhandled`: a listener throws. `RaiseBack()` is false and doesn't throw.
  - `testPauseCallsHandler`: `onPause` increments a counter, and `Host.RaisePause()` leaves it at 1.
  - `testPauseWithoutHandler`: `Host.RaisePause()` with no handler doesn't throw.
  - `testThrowingPauseIsSwallowed`: a throwing handler. `RaisePause()` returns normally.
- [ ] **Step 2: Run them to see them fail.** Run: `haxe tests/headless.hxml -D test=TestLifecycle`. Expected: compile error.
- [ ] **Step 3: Implement** the C# members and externs, then `BackButton.hx` and `AppLifecycle.hx`, with doc comments in the style of `WindowClose.hx`.
- [ ] **Step 4: Run them to see them pass.** Run: `haxe tests/headless.hxml -D test=TestLifecycle`, then the full suite. Expected: all pass.
- [ ] **Step 5: Commit.** `git commit -m "BackButton and AppLifecycle.onPause: back and going to the background, for apps"`

---

### Task 4: Long-press tooltips

A port of heaps-android's `LongPress` and `LongPressTooltips` onto HaxeUI `Screen` events. Tested headlessly. It is installed only on Android, in Task 6b.

**Files:**
- Create: `haxe/ui/backend/cs/touch/LongPress.hx` (heaps-android's `LongPress.hx`, verbatim apart from the package)
- Create: `haxe/ui/backend/cs/touch/TouchTooltips.hx`
- Modify: `native/UIEvents.cs`, `native/Host.cs`, `Native.hx` (click suppression)
- Create: `tests/cases/TestTouchTooltips.hx`. Modify: `tests/TestMain.hx`

**Interfaces:**
- Produces (C#): `public static void Host.SuppressNextClick()`. The next `CLICK` (and its `DBL_CLICK`) that `UIEvents` would synthesise from a press and release is dropped, so a long press doesn't also click. It resets on the next pointer press.
- Produces (Haxe): `haxe.ui.backend.cs.touch.TouchTooltips`, with `static function install():Void` (idempotent) and `public static inline var SLOP = 8; GAP = 6;`. Its behaviour matches heaps-android's `LongPressTooltips` (target choice, drag-registered components never arm, slop cancels, tooltip placed above and clamped to the screen width, `settle` on release). It listens on `Screen.instance.registerEvent(MouseEvent.MOUSE_DOWN/MOUSE_MOVE/MOUSE_UP, ..., Priority.HIGH)` in layout units instead of `hxd.Window` pixels. Where heaps clears `_mouseDownFlag`, it calls `Host.SuppressNextClick()` instead.

- [ ] **Step 1: Write the failing tests** in `TestTouchTooltips`. The setup adds a `Button` with `text="X"` and `tooltip="Tip"` at 20,20 and calls `TouchTooltips.install()`. The helper `tipText()` is the text of `@:privateAccess ToolTipManager.instance._toolTip` when it is non-null and not hidden, otherwise null.
  - `testHoldShowsTooltip`: `TestDriver.mouseDown(centre)`, `pump(40)`, and `tipText()` is `"Tip"`.
  - `testReleaseAfterHoldHidesAndDoesNotClick`: count the button's `CLICK`s. Hold, then `mouseUp`, `pump()`. `tipText()` is null and the count is 0.
  - `testShortTapClicksWithoutTooltip`: `mouseDown`, `pump(5)`, `mouseUp`, `pump(40)`. The count is 1 and `tipText()` is null.
  - `testMoveBeyondSlopCancels`: `mouseDown(c)`, then `mouseMove(c.x + 20, c.y)`, then `pump(40)`. `tipText()` is null.
- [ ] **Step 2: Run them to see them fail.** Run: `haxe tests/headless.hxml -D test=TestTouchTooltips`. Expected: compile error.
- [ ] **Step 3: Implement** `SuppressNextClick` at the click synthesis in `UIEvents.cs` (around line 58), then `LongPress.hx` and `TouchTooltips.hx`.
- [ ] **Step 4: Run them to see them pass.** Run the case, then the full suite. Expected: all pass. `TestMouse` is unchanged.
- [ ] **Step 5: Commit.** `git commit -m "TouchTooltips: a long press shows a tooltip, for touch screens"`

---

### Task 5: The Android build branch

The macro writes an Android project. Nothing runs on a device yet.

**Files:**
- Modify: `haxe/ui/backend/cs/macros/Build.hx`
- Create: `templates/AndroidApp.csproj`, `templates/android/MainActivity.cs`
- Create: `tests/android-app/Main.hx`, `tests/android-app/build.hxml`, `tests/android-app/check-project.sh`

**Interfaces:**
- Consumes: none.
- Produces:
  - `Build.afterGenerate`: when `haxeui_cs_android` is defined, it validates the defines, writes `<out>/<Main>.csproj` from `AndroidApp.csproj`, writes `<out>/android/MainActivity.cs` from the template, and skips `markEntryPointSta`. Unless `haxeui_cs_no_dotnet` is set, it then runs `dotnet build <csproj> -c Debug -nologo -v q`. With `haxeui_cs_run`, it then runs `adb install -r <apk>` and `adb shell monkey -p <id> -c android.intent.category.LAUNCHER 1`. `haxeui_cs_publish` together with `haxeui_cs_android` is a `fatalError` ("not supported on Android yet").
  - APK path: `<out>/bin/Debug/net10.0-android/<rid>/<id>-Signed.apk`, with `rid` = `android-arm64` or `android-x64`.
  - **Template `AndroidApp.csproj`:** the same compile, resources and packages lines as `App.csproj`, with `Avalonia.Android` in place of `Avalonia.Desktop`, plus:
    - `TargetFramework=net10.0-android` and `SupportedOSPlatformVersion=26` (raise it only if Avalonia 12 requires more)
    - `OutputType=Exe`
    - `ApplicationId`, `ApplicationTitle`, `ApplicationVersion=1`, `ApplicationDisplayVersion=1.0`
    - `RuntimeIdentifier=<rid>`
    - `EmbedAssembliesIntoApk=true`, `AndroidPackageFormat=apk`
    - `PublishTrimmed=false`, `AndroidLinkMode=None`
    - `DefineConstants` gains `HAXEUI_CS_ANDROID`
  - **Template `MainActivity.cs`:** namespace `HaxeUICs.App`.
    - `[Activity(Label = "::LABEL::", MainLauncher = true, Exported = true, Theme = "@android:style/Theme.NoTitleBar", ConfigurationChanges = Orientation | ScreenSize | ScreenLayout | SmallestScreenSize | UiMode | Keyboard | KeyboardHidden | Density)]`
    - `public class MainActivity : Avalonia.Android.AvaloniaMainActivity<HaxeUICs.HostApplication>`
    - A static `RunHaxe()` whose body is `global::cs.Boot.init(); global::::MAIN::.main();` (`::MAIN::` is the dotted main class path).
    - Wiring of the hooks Task 6 adds to `Host` (filled in there; here, a placeholder that compiles).
- Desktop path untouched: its template, packages and `[STAThread]` rewrite are unchanged.

- [ ] **Step 1: Write the fixture app.** `tests/android-app/Main.hx` is a `HaxeUIApp` showing a `Label` "android-app". In `ready`, it logs `android-app: ready <Screen.width>x<Screen.height> scale <Toolkit.scaleX>` with `Sys.println`. `build.hxml` sets `-lib haxeui-core -lib haxeui-cs -D haxeui_cs_android -D haxeui_cs_android_id=org.haxeui.cs.androidapp -D haxeui_cs_android_label=android-app -D haxeui_cs_android_abi=x86_64 -cs tests/android-app/bin`.
- [ ] **Step 2: Write the failing project check.** `check-project.sh` runs `haxe tests/android-app/build.hxml -D haxeui_cs_no_dotnet` and greps `tests/android-app/bin/Main.csproj` for each of: `<TargetFramework>net10.0-android</TargetFramework>`, `<ApplicationId>org.haxeui.cs.androidapp</ApplicationId>`, `Avalonia.Android`, `<PublishTrimmed>false</PublishTrimmed>`, `<RuntimeIdentifier>android-x64</RuntimeIdentifier>`. It checks that `Avalonia.Desktop` is absent, that `bin/android/MainActivity.cs` contains `global::Main.main();`, and that `bin/src/Main.cs` has no `[System.STAThread]`. It exits non-zero on the first miss. A second run without `haxeui_cs_android_id` must fail with `haxeui-cs: -D haxeui_cs_android needs -D haxeui_cs_android_id=<application id>`.
  Run: `bash tests/android-app/check-project.sh`. Expected: fails (no Android branch yet).
- [ ] **Step 3: Implement** the branch and the templates.
- [ ] **Step 4: Check the project and the desktop.** Run `check-project.sh`. Expected: passes. Re-run Task 1 Step 2's two commands and `diff` against `<scratch>/baseline/`. Expected: identical.
- [ ] **Step 5: Build the APK.** Run: `haxe tests/android-app/build.hxml`. Expected: the APK exists at the path above. It can't run correctly yet, because the host still needs a desktop lifetime.
- [ ] **Step 6: Commit.** `git commit -m "-D haxeui_cs_android: an Android project and MainActivity from the build"`

---

### Task 6: Host in single-view mode. The app launches, renders and takes touch

**Files:**
- Modify: `native/Host.cs`, `native/FileDialogs.cs`, `native/UIClipboard.cs`, `haxe/ui/backend/AppImpl.hx`, `Native.hx`, `templates/android/MainActivity.cs`
- Modify: `tests/android-app/Main.hx`. Create: `tests/android-app/check-device.sh`

**Interfaces:**
- Consumes: Task 5's templates. Task 3's `Host.RaisePause`.
- Produces (C# `Host`):
  - `public static double RenderScaling`: `TopLevel.RenderScaling`, or 1 before there is one. Used by the fixture.
  - `public static TopLevel TopLevel`: `Window` on the desktop, `TopLevel.GetTopLevel(Root)` otherwise. `FileDialogs`, `UIClipboard` and screen events use it instead of `Host.Window`.
  - `public static void RunSingleView(IHostListener listener)`: stores the listener and returns. When `Root` is attached and has a non-zero size, it calls `OnReady` once. Resizes of `Root` raise `OnResize`, and `ClientWidth`/`ClientHeight` read `Root.Bounds` when there is no `Window`.
  - `public static string FilesDir { get; set; }`: set by `MainActivity`.
  - `public static System.Action LeaveApp { get; set; }` and `public static System.Action FinishApp { get; set; }`: set by `MainActivity` (`MoveTaskToBack(true)` / `FinishAndRemoveTask()`).
  - `public static System.Action Entry { get; set; }`: the Haxe entry point, set by `MainActivity` to `RunHaxe`.
  - `HostApplication.OnFrameworkInitializationCompleted`: for `ISingleViewApplicationLifetime`, sets `MainView = Root` and, the first time only (a static flag), calls the `Host.Entry` action that `MainActivity` sets to `RunHaxe`.
  - `CloseWindow()` with no `Window`: calls `FinishApp`, then `Listener.OnClosed()`.
  - `Exit` / `UIClipboard.Flush`: Windows-only calls are guarded by `OperatingSystem.IsWindows()`.
- Produces (`MainActivity`): in `OnCreate`, before `base.OnCreate`, it sets `Host.FilesDir = FilesDir.AbsolutePath`, `Environment.CurrentDirectory = Host.FilesDir`, `Host.Entry = RunHaxe`, `LeaveApp` and `FinishApp`. It overrides `OnPause` to call `base` and then `Host.RaisePause()`.
- `AppImpl.init`: `#if haxeui_cs_android`, `Host.RunSingleView(new HostListener(onReady, onEnd, true))` (it pumps Haxe events as the desktop does). The window options are ignored.

- [ ] **Step 1: Extend the fixture into a device check.** In `main` (before `HaxeUIApp`), it appends a line to `runs.txt` in the current directory and logs `android-app: main ran <line count> cwd <Sys.getCwd()>`. In `ready`, it adds a `Button` "Tap me" whose click logs `android-app: clicked`, and sets `AppLifecycle.onPause` to log `android-app: paused`. Once the button is laid out, it logs `android-app: button <cx> <cy>`, the button's centre in device pixels (layout units × the Avalonia render scaling, which the fixture gets from `Host.RenderScaling`, a getter added in this task). The script taps there.
  `check-device.sh` starts with `adb logcat -c` and runs `haxe tests/android-app/build.hxml -D haxeui_cs_run`, then waits for and asserts each of the following in `adb logcat -d -s DOTNET:*`:
  1. `main ran 1 cwd /data/user/0/org.haxeui.cs.androidapp/files`, then `ready <w>x<h> scale 1`, with w,h > 0.
  2. `adb shell input tap <button centre>` (from the fixture's logged button bounds), then `clicked`.
  3. Rotation: `adb shell settings put system accelerometer_rotation 0` and `user_rotation 1`. `ready` logs no second time, and `main ran` still occurs once.
  4. `adb shell input keyevent KEYCODE_BACK`, then `paused`. Relaunch with monkey, and `main ran` still occurs once (same process).
  5. `KEYCODE_HOME`, `adb shell am kill org.haxeui.cs.androidapp`, relaunch, then `main ran 2`.
  6. No `FATAL EXCEPTION` and no `Unhandled` in the full logcat. Save `adb exec-out screencap -p` to `tests/android-app/bin/screen.png`.

  Finally it resets the rotation settings.
  Run: `bash tests/android-app/check-device.sh`. Expected: fails at 1.
- [ ] **Step 2: Implement** the `Host`, `AppImpl` and `MainActivity` changes. Replace `Host.Window` uses in `FileDialogs.cs` and `UIClipboard.cs` with `Host.TopLevel`.
- [ ] **Step 3: Run the device check.** Run: `bash tests/android-app/check-device.sh`. Expected: all 6 pass. Look at `screen.png`: the label and button are visible and not scaled twice.
- [ ] **Step 4: Desktop regression.** Run the full headless suite, then `exit-app`, `early-add`, `window-app` and `clipboard-app` per the README, and the baseline `diff`. Expected: all as before.
- [ ] **Step 5: Commit.** `git commit -m "Android: single-view host, entry from MainActivity, files dir as working directory"`

---

### Task 6b: Picker, back, keyboard, tooltips, full screen, README

**Files:**
- Modify: `native/FileDialogs.cs`, `native/Host.cs`, `haxe/ui/backend/OpenFileDialogImpl.hx`, `haxe/ui/backend/cs/macros/Build.hx`
- Create: `haxe/ui/backend/cs/macros/TouchPatches.hx`
- Modify: `templates/android/MainActivity.cs`, `tests/android-app/Main.hx`, `tests/android-app/check-device.sh`, `README.md`

**Interfaces:**
- Consumes: `PickedFiles.Import` (Task 2), `Host.RaiseBack`/`BackButton` (Task 3), `TouchTooltips.install` (Task 4), `Host.LeaveApp`/`FilesDir`/`TopLevel` (Task 6).
- Produces:
  - **`FileDialogs.OpenFiles` under `#if ANDROID`:** it ignores `patterns` and allows one file. For each file, it reads the display name from `IStorageFile.Name` and the size from `GetBasicPropertiesAsync()` (`-1` if null), then calls `PickedFiles.Import(Path.Combine(Host.FilesDir, "picked"), name, size, () => file.OpenReadAsync().Result)` and answers with the returned path. An `IOException` goes to a new `IFileDialogListener.OnFailed(string message)`. That means the extern interface in `Native.hx` and every Haxe implementation of it (`FileDialogListener` and any test listeners) gain `OnFailed(message:String):Void`. Desktop implementations route it to cancel, so desktop behaviour doesn't change.
  - **`OpenFileDialogImpl`:** handles `onFailed` with `Dialogs.messageBox(message, title, MessageBoxType.TYPE_ERROR)` and then `dialogCancelled()`, as haxeui-heaps does. The desktop path is unchanged (desktop never calls `OnFailed`).
  - **Back:** `Host` subscribes to `TopLevel.BackRequested`. If `!RaiseBack()`, it calls `LeaveApp()`. It always sets `e.Handled = true`, so Avalonia never finishes the activity.
  - **Immersive:** on attach, `TopLevel.InsetsManager` hides the system bars and draws edge to edge (check the Avalonia 12 property names, `IsSystemBarVisible` / `DisplayEdgeToEdgePreference`).
  - **`TouchPatches.init()`:** called from `Build.configure` only `#if haxeui_cs_android`. It is a build macro on `haxe.ui.tooltips.ToolTipManager` that replaces `registerTooltip` with heaps-android's `noHoverTooltips` body, calling `haxe.ui.backend.cs.touch.TouchTooltips.install()`.
  - **Keyboard:** no code. `check-device.sh` verifies it.

- [ ] **Step 1: Extend the device check.** The fixture adds a `TextField`, an "Open" button that opens `Dialogs.openFile` with `readContents:true`, `readAsBinary:true` and logs `android-app: opened <fullPath> <bytes.length>`, a button with `tooltip="Tip"`, and a `BackButton` listener that is armed by a "Trap back" button. That listener logs `android-app: back trapped` and returns true once.
  New steps:
  - **Keyboard:** tap the `TextField`. `adb shell dumpsys input_method | grep mInputShown=true` matches.
  - **Back trapped:** tap "Trap back", then `KEYCODE_BACK`. Logs `back trapped` and no `paused`.
  - **Immersive:** `adb shell dumpsys window | grep -E "statusBars.*visible=false|mStatusBar.*isVisible=false"` matches. Pick whichever line this API 36 image prints, and note it in the script.
  - **Picker, by hand** (the script stops and prints these steps, then waits for Enter): `adb push tests/assets/red4x4.png /sdcard/Download/pick.png`, tap Open, choose `pick.png` in Downloads. Logs `opened /data/user/0/org.haxeui.cs.androidapp/files/picked/pick.png <n>`, where n is the file's size. Pick it again and the same path is logged.
  - **Tooltip, by hand:** a long press on the tooltip button shows "Tip" above it, and letting go doesn't click.

  Run it. Expected: the new automated steps fail.
- [ ] **Step 2: Implement** the items above.
- [ ] **Step 3: Run the device check.** Run: `bash tests/android-app/check-device.sh`. Expected: all automated steps pass, and the by-hand steps behave as described.
- [ ] **Step 4: README.** Add an "Android" section in the style of the "Linux" and "Publishing" sections. Cover:
  - the four defines, the requirements (the `android` workload, adb), and that a debug APK installs with `haxeui_cs_run`;
  - that `main` runs from `MainActivity` once per process with the files dir as the working directory, and `ready()` returns at once;
  - `BackButton`, `AppLifecycle.onPause`, picked files copied into `files/picked/`, long-press tooltips, immersive mode;
  - what is not supported: publish, trimming, folder and save dialogs (they cancel);
  - `tests/android-app/check-device.sh`, with the by-hand steps.

  Also add `BackButton` and `AppLifecycle` to the API notes near `WindowClose`.
- [ ] **Step 5: Desktop regression.** Same as Task 6 Step 4.
- [ ] **Step 6: Commit.** `git commit -m "Android: picked files, back, long-press tooltips, immersive; README"`

---

### Task 7: EpubReader on the emulator (EpubReader repo)

**Files:**
- Create: `D:/_github/EpubReader/build.cs.android.hxml`
- Modify: `D:/_github/EpubReader/app/Main.hx`

**Interfaces:**
- Consumes: `haxe.ui.backend.cs.AppLifecycle.onPause` (Task 3). The Android defines (Task 5).

- [ ] **Step 1: Write `build.cs.android.hxml`.** Start from `build.cs.hxml` minus `-D windowSize` and the `--next`/`--cmd` lines. Add `-D haxeui_cs_android`, `-D haxeui_cs_android_id=com.joewilliamson.epubreader.cs`, `-D "haxeui_cs_android_label=Reader (C#)"` and `-D haxeui_cs_android_abi=x86_64`, with `-cs bin/cs-android`. Write a header comment in the style of `build.android.hxml`: what this is, and that it sits beside that build. Note in a comment that dropping the `abi` line builds for an arm64 phone.
- [ ] **Step 2: Add the pause hook.** In `Main.hx`'s `ready`, after `app.start()`, add `#if cs haxe.ui.backend.cs.AppLifecycle.onPause = view.saveNow; #end`, with a comment explaining that it closes the `SAVE_DELAY_MS` window when the app goes to the background.
- [ ] **Step 3: Desktop is unchanged.** Run: `haxe build.cs.hxml` (the reader opens; close it) and `haxe test.hxml`. Expected: as before.
- [ ] **Step 4: Build and install.** Run: `haxe build.cs.android.hxml -D haxeui_cs_run`. Expected: Reader (C#) launches into the shelf. Then `adb shell pm list packages | grep epubreader` shows `com.joewilliamson.epubreader.cs`, next to the heaps one if that is installed.
- [ ] **Step 5: Acceptance on the emulator.** By hand, each item recorded pass or fail:
  - [ ] It fills the screen with no status bar, and rotating keeps the place.
  - [ ] Tapping toolbar buttons works, and dragging scrolls the shelf and a chapter.
  - [ ] **Scale:** a toolbar button's height in `screencap` pixels is within 15 % of heaps-android's on the same emulator (heaps uses whole-number scale 3, so 39 units is 117 px). If it is outside that, stop and bring it back to Joe (the spec's rule).
  - [ ] `adb push <an .epub> /sdcard/Download/`, then Open, Downloads, the book. It opens and reads.
  - [ ] A built-in shelf book opens.
  - [ ] Turn a few pages, then Home, `adb shell am kill com.joewilliamson.epubreader.cs`, relaunch. The same book is open at the same place, and it is in the recent list.
  - [ ] Turn a page and press Home within 1 s, then kill and relaunch. The place is kept (the pause hook).
  - [ ] A text field (search or settings, if present) brings up the keyboard.
  - [ ] Back with nothing open goes to the background, and relaunch resumes without a restart.
  - [ ] No `FATAL EXCEPTION` in `adb logcat -d`.
- [ ] **Step 6: arm64 packages.** Run: `haxe build.cs.android.hxml -D haxeui_cs_android_abi=arm64-v8a -D haxeui_cs_no_dotnet`, and then `dotnet build bin/cs-android/Main.csproj -c Debug -p:RuntimeIdentifier=android-arm64`. Expected: `bin/cs-android/bin/Debug/net10.0-android/android-arm64/com.joewilliamson.epubreader.cs-Signed.apk` exists. It isn't installed anywhere.
- [ ] **Step 7: Commit (EpubReader).** `git add build.cs.android.hxml app/Main.hx`, then `git commit -m "build.cs.android.hxml: the reader on Android through haxeui-cs"`
