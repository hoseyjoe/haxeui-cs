# haxeui-cs on Android — design

Date: 2026-10-29

## Intent

haxeui-cs builds a HaxeUI app into an Avalonia program for Windows, Linux and the Mac. This adds
Android as one more target of the same backend, chosen with a define, so that any haxeui-cs app
can be installed on a phone without Android code of its own.

The point is **having target options**. EpubReader already reaches Android through Heaps
(`build.android.hxml`: HashLink/C → NDK → APK via the heaps-android haxelib). The C# route sits
beside that one; it replaces nothing. EpubReader is the first app to use it, and it is the
yardstick: the C# Android build must do everything the heaps-android build does today.

## Goals

1. `-D haxeui_cs_android` turns a haxeui-cs build into a `net10.0-android` app: haxe writes the
   C#, the macro writes an Android `.csproj` (and the few Android files it needs), and `dotnet`
   builds a debug APK. With `-D haxeui_cs_run` it is installed on the connected device or running
   emulator and launched.
2. **App code is unchanged.** The same Haxe `Main` runs on desktop and Android: `new HaxeUIApp(...)`,
   `app.ready(...)`, `app.addComponent(...)`, `app.start()`. Window-only options (size, title,
   resizable, minimum size, maximized, icon) are accepted and ignored.
3. EpubReader builds with a new `build.cs.android.hxml` — its `build.cs.hxml` plus the define, an
   app id and a label — and in the emulator (`Medium_Phone_API_36.1`, x86_64) it does all of the
   below. The emulator is the completion gate: there is no phone to test on for now. An arm64
   build must still compile and package, and is checked on a phone by hand later; that check
   does not block completion. In the emulator it:
   - installs and launches into the shelf, filling the screen (immersive, as heaps-android is),
     and survives rotation without restarting or losing its place;
   - responds to touch: a tap is a click, dragging scrolls the shelf and the book;
   - opens an EPUB through the system file picker, including from Downloads or a cloud provider;
   - reads it, with the built-in shelf (`haxe.Resource` books) present as on desktop;
   - remembers the open book, the place in it and the recent list across launches, including
     after Android kills the process in the background;
   - shows the soft keyboard when a text field takes focus, and hides it after.
4. Desktop is untouched: the headless suite and the desktop checks (`exit-app`, `early-add`,
   `window-app`, `clipboard-app`) pass exactly as before, and a desktop build's `.csproj` is the
   same as today's.

## Non-goals

- Release builds, signing for the store, `.aab` bundles, trimming, AOT. Debug APKs installed over
  USB/adb are enough. (Trimming must stay **off** in whatever is built: Haxe and HaxeUI find
  classes by name at run time — README, Publishing.)
- ABIs other than arm64-v8a for a phone and x86_64 for the emulator.
- iOS, the browser, or any other Avalonia platform, even where the same host change would help.
- New reader features for phones. Back closing the topmost popup, opening links, choosing a books
  folder: none of these work on heaps-android today and none are added here.
- Save dialogs and folder dialogs on Android beyond not crashing (they answer "cancelled").

## Anti-goals

- A fork. No `haxeui-cs-android` library, no second copy of `native/`. Android is a define inside
  haxeui-cs, as `haxeui_cs_headless` and `haxeui_cs_publish` are.
- Asking apps to `#if` for Android to get ordinary behaviour (picking a file, saving state,
  scaling to the screen). If EpubReader needs an Android branch to do what it does on
  heaps-android, the backend is missing something.
- Changing the shape of HaxeUI's file dialog API (`SelectedFileInfo` with a usable `fullPath`).

## What the heaps-android build does today (the behaviour to match)

Found by reading EpubReader, haxeui-heaps (`OpenFileDialogImpl`) and heaps-android
(`hxheaps-android/haxe/ui/backend/android/*`, `android-shell/.../sdl_main_shim.c`):

| Concern | heaps-android today | Where |
|---|---|---|
| Picking a file | `ACTION_OPEN_DOCUMENT` with `*/*` (extension filters deliberately ignored: providers report `.epub` as octet-stream and `.md` as nothing); the chosen document is **copied into `<filesDir>/picked/`** and the dialog returns that real path, so `sys.io.File` reads it and the recent list can reopen it after the original is gone. One file only. A failure shows a message box, then cancels. | haxeui-heaps `OpenFileDialogImpl` (`heaps_android`), heaps-android `FileDialog.openToFile` |
| Where state goes | The shim `chdir`s to the app's private files dir before `main`. EpubReader's `StateStore.defaultPath()` finds no `EPUB_STATE`/`APPDATA` and returns the relative `epubreader-state.json`, which therefore lands in `filesDir`. | `sdl_main_shim.c`, `StateStore` |
| Saving | The reader saves 1 s after the last scroll or page turn (`SAVE_DELAY_MS`), so a killed process loses at most that second. | `MainView.scheduleSave` |
| Back | EpubReader registers no `BackButton` listener, so back is unhandled and does `moveTaskToBack` — the app goes to the background without finishing. | heaps-android `BackButton` |
| Soft keyboard | Shown when a text input takes focus, hidden when it loses it. | `AndroidPatches.softwareKeyboard` |
| Scale | HaxeUI's dpi is the device's real density; EpubReader additionally sets a whole-number `Toolkit.scale` so the 360-unit design width fills the short edge (≈ 48 dp touch targets). | `AndroidPatches.screenDpi`, `Main.hx` (`heaps_android` only) |
| Tooltips | No hover on a finger: hover tooltips are disarmed and a long press shows the tooltip instead. | `AndroidPatches.noHoverTooltips`, `LongPressTooltips` |
| Full screen | Immersive; the status bar stays hidden. | `WindowSetup` |
| Already unavailable | Folder picker (`FolderPicker.available()` is false off desktop HL), external links (`ExternalUrl.open` runs `rundll32`, which fails and returns false). | EpubReader |

## How it works (decided)

### Start-up: Android starts the activity, the activity starts Haxe

On the desktop, Haxe's `Main` is the process entry point and `ready()` blocks inside Avalonia's
loop. On Android the OS starts an activity, so the order inverts:

1. A generated `MainActivity : AvaloniaMainActivity<HostApplication>` is the launcher activity.
2. `HostApplication.OnFrameworkInitializationCompleted` sees an `ISingleViewApplicationLifetime`
   and sets its `MainView` to `Host.Root` (the same `UIPanel` the desktop window takes as content).
3. Before the first call into Haxe, the working directory is set to the app's private files dir
   (`Environment.CurrentDirectory = <filesDir>`), so relative paths behave as on heaps-android.
4. It then calls the Haxe program's entry point **once per process** (an activity recreated in the
   same process reattaches the existing `Root`; it does not run `main` again).
5. `main` runs as written. `new HaxeUIApp()` → `ready()` → `AppImpl.init` registers the host
   listener and **returns immediately**; `OnReady` fires once `Root` is attached and has a size,
   and from then on Haxe's event loop is pumped by the dispatcher exactly as on the desktop
   (`Host.StartEventsPump`).

`Host.Window` stops being the thing everything hangs off: clipboard, the storage provider and input
go through the `TopLevel` that holds `Root` (a `Window` on the desktop, the Android view's top level
on Android).

### Build: `-D haxeui_cs_android`

`Build.hx` gains an Android branch beside headless and publish:

- `TargetFramework` `net10.0-android`, `SupportedOSPlatformVersion` set to what Avalonia 12 needs,
  `OutputType` `Exe`, no `[STAThread]` rewrite.
- Packages: `Avalonia.Android` instead of `Avalonia.Desktop`; the rest unchanged.
- `ApplicationId` from `-D haxeui_cs_android_id=<id>`, launcher label from
  `-D haxeui_cs_android_label=<label>`; both required (a clear `fatalError` if missing).
- `PublishTrimmed`/linking off, explicitly, in Debug and Release.
- The generated `MainActivity.cs` (and an `AndroidManifest.xml` if the SDK's generated one cannot
  carry what is needed) come from `templates/`, as `App.csproj` does today.
- Default ABI arm64-v8a (a phone). `-D haxeui_cs_android_abi=x86_64` for the emulator, which is
  what every check in this work runs on.
- `haxeui_cs_run`: install and launch on the one connected device (`dotnet build -t:Run` or adb).

The desktop branch's output must be byte-for-byte what it is today.

### File picker: copy in, hand back a path

On Android, `OpenFileDialogImpl` uses Avalonia's storage provider, then **copies the picked
document into `<filesDir>/picked/<display name>`** and returns that path in `fullPath` (reading
`bytes`/`text` from the copy when `readContents` is set). This is heaps-android's contract, so
EpubReader's `onOpenClick`, its recent list and `fileExists` work unchanged. Extension filters are
not passed to the picker (the same reason heaps-android gives). One file. A failure shows a
message box, then cancels.

### Back, keyboard, tooltips, full screen

- **Back:** Avalonia's `TopLevel.BackRequested`. haxeui-cs exposes an app-facing listener API with
  the same shape as heaps-android's `BackButton` (`addListener(fn:Void->Bool)`, newest first, first
  `true` wins). Unhandled back moves the task to the background (`MoveTaskToBack(true)`), never
  finishes the activity. EpubReader registers nothing, as today.
- **Keyboard:** Avalonia's `TextBox` raises and dismisses the input method on Android by itself;
  `UITextInput` must not suppress that.
- **Tooltips:** on Android, hover tooltips are not armed; a long press shows a component's tooltip.
- **Full screen:** immersive, status and navigation bars hidden, as heaps-android.

### Lifecycle: save when going to the background

haxeui-cs raises a "paused" notification when the activity goes to the background
(`haxe.ui.backend.cs.AppLifecycle.onPause`, or similar). EpubReader's `Main` hooks it to
`view.saveNow()` — the one line of EpubReader code this adds, and it is not Android-specific (the
hook simply never fires on the desktop). This closes the one-second window `SAVE_DELAY_MS` leaves.

## EpubReader side

- `build.cs.android.hxml`: `build.cs.hxml` without `windowSize` and without the trailing
  `--cmd …Main.exe`, plus `-D haxeui_cs_android`,
  `-D haxeui_cs_android_id=com.joewilliamson.epubreader.cs`,
  `-D haxeui_cs_android_label=Reader (C#)` *(my call: its own id so both Android builds can be
  installed side by side)*, output to `bin/cs-android`.
- `Main.hx`: the pause hook above. Nothing else.
- Probing EpubReader on a device or emulator must not touch the user's real reader state
  (`EPUB_STATE`/scratch state rule) — on a device that means a separate emulator/AVD or clearing
  the app's data, never the desktop `state.json`.

## Constraints

- Haxe 4.3.x, .NET 10 SDK with the `android` workload (installed: 36.1), Avalonia 12.1.4. Android
  SDK, adb and an emulator image (`Medium_Phone_API_36.1`) are installed on the dev machine.
- haxeui-core-joe, not upstream.
- haxeui-cs's working tree currently has uncommitted clipboard work (clipboard history formats in
  `UIClipboard.cs`, the `clipboard-app` changes), and EpubReader's `build.cs.hxml` change
  (`bin/cs`, the trailing `--cmd`) is uncommitted too. *(My call:)* the Android work waits until
  both are committed and builds on top of them, so "desktop untouched" is measured against that
  state, and the clipboard history code is among what gets fenced off on Android.
- JVM tools may not run from an agent shell: EpubReader's 2026-09-17 file-picker spec records
  gradle failing there ("the JVM fails to open a `Selector`"). A `net10.0-android` build also runs
  javac/d8. *(My call:)* the plan's first task is a smoke build of an empty Avalonia Android app
  from the agent shell. If it builds and installs, Android checks are verification steps inside
  each task; if it does not, each Android task ends in a by-hand checklist for Joe and builds are
  batched around his runs.
- Haxe emits `Array`, `Math`, `Std`… into the global namespace: native C# always writes
  `System.Math` etc. (see `Host.cs` header).

## Left to the builder

- Scale. Avalonia lays out in device-independent units, so a 1080-px phone is about 400 units
  wide and HaxeUI should probably run at `Toolkit.scale` 1 under it. What must hold: the reader's
  controls end up roughly the size they are on heaps-android (within ~15 %), and EpubReader's
  `Toolkit.autoScale = true` does not scale twice. If that cannot be had without an app change,
  bring it back.
- Exactly how the Haxe entry point is invoked from C# (the generated `Main` class's static method
  or a hook the macro writes), and how "once per process" is guarded.
- What `app.exit()` means on Android (finish, or to the background) — nothing in EpubReader calls
  it.
- How `picked/` handles two documents with the same display name — match heaps-android's
  behaviour; read its Kotlin side to find it.
- The minimum Android API level, within what Avalonia 12 supports.
- Windows-only native code (`OleFlushClipboard`, clipboard history formats) behind runtime or
  compile-time OS checks so Android neither links nor calls it.
- How to automate the Android checks. The bar: a scripted emulator run that installs, launches,
  takes a screenshot (`adb exec-out screencap`) and checks logcat for an unhandled exception;
  picking a file and the kill-and-relaunch check may be by hand, written down as steps in the
  README like the clipboard-app check is.
- README: an Android section in the style of the existing Linux and Publishing sections.
