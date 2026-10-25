# haxeui-cs Feature Completeness Implementation Plan

> Paths are placeholders for the checkouts this was written against: `<haxeui-cs>` (this repo), `<haxeui-core-joe>` and `<haxeui-html5>` (haxelib checkouts), `<JoeClash>` and its worktrees `<JoeClash-cs>` and `<JoeClash-gate>`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make haxeui-cs a complete HaxeUI backend. Fix the bugs the 2026-10-23 inventory found, add what Joeditor needs (font files, shadows, text shadow, blur), then reach html5 parity on every remaining style, input and app feature. Finish with Linux and Mac runs.

**Architecture:** Two layers, as in v1:
- `native/*.cs` (namespace `HaxeUICs`) does all the Avalonia work and knows nothing of HaxeUI.
- The `haxe/ui/backend/*Impl.hx` contract files sit on externs in `haxe/ui/backend/cs/native/Native.hx`.

New drawing features become fields or methods on `UIStyle`, `UIPanel`, `UIText` and `UITextInput`, filled in by `StyleMapper` and the `*Impl` classes. Core fixes go to haxeui-core-joe master.

**Tech Stack:** Haxe 4.3.7 (C# target), .NET 10, Avalonia 12.1.4 (Skia), utest, haxeui-core-joe, haxeui-html5 (reference only).

**Spec:** `docs/superpowers/specs/2026-10-23-haxeui-cs-feature-complete-design.md`. Goal numbers below ("G7") are the spec's.

## Global Constraints

**Toolchain and repos**
- Haxe 4.3.7, .NET 10 (`net10.0`), Avalonia 12.1.4. haxeui-core-joe (`<haxeui-core-joe>`) is the `haxelib dev` checkout every build uses.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nothing is ever pushed.

**Core-joe changes**
- They are `#if cs` / `#if haxeui_cs`, or correct on every target. Commit each one straight to haxeui-core-joe master (`git -C <haxeui-core-joe> ...`).
- They must not change behaviour on html5 or heaps.

**JoeClash**
- Never touch `<JoeClash>` (Joe's checkout, which has his uncommitted work).
- Gates run in a detached worktree, `<JoeClash-gate>`, created from `main` the first time it is needed:
  ```
  git -C <JoeClash> worktree add --detach <JoeClash-gate> main
  ```
- Nothing is committed to JoeClash. Task 38 removes the worktree.
- **The Joeditor gate:** in `<JoeClash-gate>`, run
  ```
  haxe tools.joeditor.cs.hxml -D haxeui_cs_headless
  ```
  then
  ```
  dotnet bin/JoeditorCs/bin/Debug/net10.0/Joeditor.dll --cs-accept
  ```
  It must print `accept: OK` and exit 0. Untracked art the run needs is copied (never moved) from `<JoeClash>`.
- **The heaps gate**, after any core-joe commit: in the gate worktree, `haxe tests.hxml` passes 353/353, and `haxe tools.joeditor.hxml` still builds.

**Tests**
- A goal's test is written first and seen to fail. Single case: `haxe tests/headless.hxml -D test=<Case>`. Single test: add `-D "UTEST_PATTERN=<name>"`.
- Whole suite: `haxe tests/headless.hxml`. It passes with exit code 0 and `ALL TESTS OK` in the report. A failing run exits 1 and names the failing test.
- Every new test case class is added to `TestMain.cases()` in `tests/TestMain.hx`.
- Colours in tests and styles are 6-digit hex. Core reads `#f00` as `0x000F00`.
- The headless window background is white (`0xFFFFFFFF`). Root components without a background show it.

**Behaviour**
- html5 (`<haxeui-html5>`) is the behaviour reference, shadows and filters included. The one heaps item is 9-slice with repeated edges (G17).
- A feature that cannot be done properly goes in the README's "Limits", with the reason. It is never shipped half-working.

## Review Focus

Each line names an input or condition the spec implies, and what a reasonable person expects. Its test is added to the task named.

1. **A filter switched off again.** Themes set `filter: none` on hover and down states. A shadow or blur that is set and then cleared leaves no trace. *Task 12 `testShadowClears`, Task 14 `testBlurClears`, Task 23 `testColourFilterClears`.*
2. **A font that is missing or isn't a font.** It falls back to the default family with no exception. *Task 11 `testMissingFontFallsBack`, `testNotAFontFallsBack`.*
3. **Root components added after `Toolkit.scale` is set**, such as popups and dropdown lists, are scaled too. *Task 24 `testPopupIsScaled`.*
4. **The text-shadow style present before the text exists**, or the text replaced later, still shadows the glyphs. *Task 13 `testShadowSetBeforeText`.*
5. **A colour filter over backgrounds, images and canvas drawings, not only text.** *Task 23 `testFilterReachesImageAndCanvas`.*
6. **An HTTP image whose component is removed before the response arrives.** No exception, and nothing drawn. *Task 5 `testHttpImageAfterRemoval`.*

---

### Task 1: Parity gallery tool

Promote the throwaway probe (`spike/probe/`, gitignored) to a committed tool. It builds the same pages for haxeui-cs and html5, and writes side-by-side PNGs.

**Files:**
- Create: `tools/gallery/Gallery.hx`, from `spike/probe/Probe.hx`.
  - Keep its entries, samples, `buildPage`, `PER_PAGE = 24` and the 1440×900 window.
  - Output goes to `tools/gallery/out/` instead of `spike/probe/out/`.
- Create: `tools/gallery/ClassList.hx`. A build macro that walks core's `haxe/ui/components` and `haxe/ui/containers` source folders and produces `Gallery.CLASSES:Array<String>`. It replaces the generated `Classes.hx`.
- Create: `tools/gallery/gallery.cs.hxml` (from `spike/probe/probe.hxml`). Includes `--macro include('haxe.ui.components')` and `--macro include('haxe.ui.containers', true)`.
  - Until Task 9 lands, it keeps the probe's exclusion list for `Collapsible`, `SideBar` and `properties.*`.
- Create: `tools/gallery/gallery.html5.hxml`, from `spike/probe/probe-html5.hxml`.
- Create: `tools/gallery/web/index.html`, from `spike/probe/web/index.html`.
- Create: `tools/gallery/compare.py`. It serves `tools/gallery/web` with `http.server` on port 8765 and photographs each page with headless Edge:
  ```
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu --hide-scrollbars --window-size=1440,900 --virtual-time-budget=4000 --screenshot=<png> "http://localhost:8765/index.html?page=<n>&dark=<0|1>"
  ```
  It writes `out/compare/page<n>[-dark].png`: the top 430 px of the cs page above the same strip of the html5 page. It runs with `python -I`.
- Modify: `.gitignore`. Add `tools/gallery/out/`, `tools/gallery/bin/` and `tools/gallery/web/gallery.js`.
- Modify: `README.md` "Testing". One paragraph on the gallery and its three commands.

**Interfaces:**
- Produces: the commands later tasks call "the gallery run":
  - `haxe tools/gallery/gallery.cs.hxml`
  - `dotnet tools/gallery/bin/bin/Debug/net10.0/Gallery.dll`, then the same with `--dark`
  - `haxe tools/gallery/gallery.html5.hxml`
  - `python -I tools/gallery/compare.py`

- [ ] **Step 1: Create the files above.** The macro list replaces `Classes.hx`; everything else is moved from the probe.
- [ ] **Step 2: Run the cs build and both themes.**
  Run: `haxe tools/gallery/gallery.cs.hxml && dotnet tools/gallery/bin/bin/Debug/net10.0/Gallery.dll && dotnet tools/gallery/bin/bin/Debug/net10.0/Gallery.dll --dark`
  Expected: prints `gallery: <n> entries, <p> pages` twice, with n ≥ 130. `tools/gallery/out/page0.png` … and `page0-dark.png` … exist.
- [ ] **Step 3: Run the html5 build and the comparison.**
  Run: `haxe tools/gallery/gallery.html5.hxml && python -I tools/gallery/compare.py`
  Expected: `tools/gallery/out/compare/page<n>.png` for every page, in both themes. Open `page0.png`: the cs strip is above the html5 strip, and both show the same 24 cells.
- [ ] **Step 4: Commit.**
  ```bash
  git add tools/gallery .gitignore README.md
  git commit -m "Gallery: every component and style sample, haxeui-cs beside html5"
  ```

---

## Phase 1: bugs

### Task 2: TextArea wraps (G1)

**Files:**
- Modify: `native/UITextInput.cs`, `SetWordWrap`.
- Modify (only if Step 5 still fails): `haxe/ui/backend/TextInputImpl.hx`, `validateStyle`.
- Test: `tests/cases/TestTextInput.hx`.

**Interfaces:** none new.

- [ ] **Step 1: Write the failing tests** in `TestTextInput`:

```haxe
function testTextAreaWrapsWhenAsked() {
	var ta = longTextArea();
	ta.wrap = true;
	Screen.instance.addComponent(ta);
	TestDriver.pump(3);
	var input = ta.getTextInput().inputNative;
	Assert.isTrue(input.ExtentWidth <= 150, 'extent ${input.ExtentWidth}');
	Assert.isTrue(input.ExtentHeight > 40, 'extent ${input.ExtentHeight}');
}

function testTextAreaWrapsByDefault() { // TextArea declares wrap = true; html5 wraps every textarea
	var ta = longTextArea();
	Screen.instance.addComponent(ta);
	TestDriver.pump(3);
	Assert.isTrue(ta.getTextInput().inputNative.ExtentWidth <= 150);
}

function testTextAreaWithoutWrapScrollsSideways() {
	var ta = longTextArea();
	ta.wrap = false;
	Screen.instance.addComponent(ta);
	TestDriver.pump(3);
	Assert.isTrue(ta.getTextInput().inputNative.ExtentWidth > 150);
}

static function longTextArea():TextArea {
	var ta = new TextArea();
	ta.width = 150;
	ta.height = 90;
	ta.text = "A textarea with enough words in it to wrap across several lines, and then some more.";
	return ta;
}
```

- [ ] **Step 2: Run them; the two wrap tests fail.**
  Run: `haxe tests/headless.hxml -D test=TestTextInput`
  Expected: FAIL in `testTextAreaWrapsWhenAsked` and `testTextAreaWrapsByDefault`. The extent width is well over 150.
- [ ] **Step 3: Implement.** In `UITextInput.SetWordWrap(bool wrap)`, also set the horizontal scrollbar: `ScrollBarVisibility.Disabled` when wrapping, `Hidden` when not. `Hidden` still lets the content be infinitely wide.
- [ ] **Step 4: Run the case.**
  Run: `haxe tests/headless.hxml -D test=TestTextInput`
  Expected: PASS, unless `testTextAreaWrapsByDefault` still fails.
- [ ] **Step 5: Only if `testTextAreaWrapsByDefault` still fails, handle the default.** The cause would be that TextArea's declared default (`wrap = true`) never reaches the text input. Fix it in `TextInputImpl.validateStyle`: wrap when `_displayData.wordWrap` is true, or when `parentComponent` is a `TextArea` whose `wrap` is true. Re-run Step 4: PASS.
- [ ] **Step 6: Run the whole suite**, then commit.
  Run: `haxe tests/headless.hxml`. Expected: `ALL TESTS OK`.
  ```bash
  git add native/UITextInput.cs haxe/ui/backend/TextInputImpl.hx tests/cases/TestTextInput.hx
  git commit -m "TextArea wraps: a wrapping TextBox needs its horizontal scrollbar disabled, not hidden"
  ```

### Task 3: Native focus matches HaxeUI focus (G2)

A new TextArea showed a caret and the focus border with nobody clicking it. Core's `FocusManager.pushView` auto-focuses the first interactive component of a new view. The invariant to hold: **a text input has native keyboard focus exactly when HaxeUI says it is focused.**

Do not add a native-to-HaxeUI focus bridge. `TextInputImpl`'s `OnFocus` stays empty: Joeditor commits its fields on FOCUS_OUT (spec G2).

**Files:**
- Test: `tests/cases/TestTextInput.hx`.
- Modify: wherever the cause is found. Use superpowers:systematic-debugging. Likely candidates are `TextInputImpl.focus()`, `UITextInput`, or how Avalonia moves focus when a focused control is detached.

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test.** It reproduces the gallery's page: a view with a list first, then a TextField, then a TextArea built in code.

```haxe
function testNativeFocusMatchesHaxeUIFocus() {
	var view = new VBox();
	var list = new ListView();
	var field = new TextField();
	var area = new TextArea();
	area.text = "made in code";
	view.addComponent(list);
	view.addComponent(field);
	view.addComponent(area);
	Screen.instance.addComponent(view);
	TestDriver.pump(3);
	for (c in ([field, area] : Array<InteractiveComponent>)) {
		Assert.equals(c.focus, c.getTextInput().inputNative.IsFocused, 'native focus of ${c.className}');
	}
	TestDriver.clickComponent(area);
	TestDriver.pump(2);
	Assert.isTrue(area.focus && area.getTextInput().inputNative.IsFocused);
	Assert.isFalse(field.getTextInput().inputNative.IsFocused);
}
```

- [ ] **Step 2: Run it.**
  Run: `haxe tests/headless.hxml -D test=TestTextInput -D "UTEST_PATTERN=testNativeFocusMatchesHaxeUIFocus"`
  Expected: FAIL, with native focus on a text input HaxeUI does not consider focused.
  - If it passes, the caret came from HaxeUI's own auto-focus, and html5 does the same. Ledger that as a ruling, keep the test, and skip to Step 5.
- [ ] **Step 3: Find the cause and fix it** (systematic-debugging). Native focus follows HaxeUI's `focus`, never the reverse.
- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  Run: `haxe tests/headless.hxml`. Expected: `ALL TESTS OK`.
  ```bash
  git add -A native haxe tests
  git commit -m "Native keyboard focus follows HaxeUI's focus"
  ```

### Task 4: Browser key codes (G3)

**Files:**
- Modify: `native/UIEvents.cs`, `KeyCodes.FromKey`.
- Create: `tests/cases/TestKeys.hx`, registered in `TestMain`.

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test.** Keys are pressed into the window with `TestDriver.key(<Avalonia Key name>)`. Screen KEY_DOWN hears them.

```haxe
class TestKeys extends utest.Test {
	static var EXPECTED:Array<{key:String, code:Int}> = [
		{key: "A", code: 65}, {key: "Enter", code: 13},
		{key: "CapsLock", code: 20}, {key: "Pause", code: 19}, {key: "PrintScreen", code: 44},
		{key: "LWin", code: 91}, {key: "RWin", code: 92}, {key: "Apps", code: 93},
		{key: "Multiply", code: 106}, {key: "Add", code: 107}, {key: "Subtract", code: 109},
		{key: "Decimal", code: 110}, {key: "Divide", code: 111},
		{key: "F13", code: 124}, {key: "F24", code: 135},
		{key: "NumLock", code: 144}, {key: "Scroll", code: 145},
		{key: "OemSemicolon", code: 186}, {key: "OemPlus", code: 187}, {key: "OemComma", code: 188},
		{key: "OemMinus", code: 189}, {key: "OemPeriod", code: 190}, {key: "OemQuestion", code: 191},
		{key: "OemTilde", code: 192}, {key: "OemOpenBrackets", code: 219}, {key: "OemPipe", code: 220},
		{key: "OemCloseBrackets", code: 221}, {key: "OemQuotes", code: 222}, {key: "OemBackslash", code: 226},
	];

	function testBrowserKeyCodes() {
		var codes:Array<Int> = [];
		var listener = (e:KeyboardEvent) -> codes.push(e.keyCode);
		Screen.instance.registerEvent(KeyboardEvent.KEY_DOWN, listener);
		for (k in EXPECTED) {
			codes = [];
			TestDriver.key(k.key);
			TestDriver.pump();
			Assert.equals(k.code, codes[0], k.key);
		}
		Screen.instance.unregisterEvent(KeyboardEvent.KEY_DOWN, listener);
	}
}
```

- [ ] **Step 2: Run it.**
  Run: `haxe tests/headless.hxml -D test=TestKeys`
  Expected: FAIL. CapsLock gives 8, LWin 70, Multiply 84, and so on.
- [ ] **Step 3: Implement** the full table in `KeyCodes.FromKey`. Every Avalonia key with a browser `keyCode` maps to it. Keys with no browser equivalent map to 0 instead of falling through to `(int)key`.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native/UIEvents.cs tests/cases/TestKeys.hx tests/TestMain.hx
  git commit -m "Key codes: the browser table for every key Avalonia reports"
  ```

### Task 5: HTTP images off the UI thread (G4, core-joe)

**Files:**
- Modify (core-joe): `haxe/ui/loaders/image/HttpImageLoader.hx`, the `#elseif cs` branch.
- Modify: `native/TestDriver.cs`, `haxe/ui/backend/cs/TestDriver.hx`, `haxe/ui/backend/cs/native/Native.hx` (a local HTTP server for tests).
- Modify: `templates/App.csproj`. Drop `SYSLIB0014` from `NoWarn` once nothing uses `WebRequest`.
- Test: `tests/cases/TestImages.hx`.

**Interfaces:**
- Produces:
  - `HeadlessDriver.StartHttpServer(string root): int` serves files from `root` on `127.0.0.1` and returns the port; unknown paths get 404.
  - `HeadlessDriver.StopHttpServer(): void`.
  - Haxe: `TestDriver.startHttpServer(root:String):Int` and `TestDriver.stopHttpServer():Void`.

- [ ] **Step 1: Write the failing tests.** Copy `tests/assets/red4x4.png` to `tests/bin/http/red.png` in `setup`, and stop the server in `teardown`.

```haxe
function testHttpImageLoadsWithoutBlocking() {
	var port = TestDriver.startHttpServer("tests/bin/http");
	var got:ImageInfo = null, called = false;
	new HttpImageLoader().load('http://127.0.0.1:$port/red.png', info -> { called = true; got = info; });
	Assert.isFalse(called, "the load must not finish inside load()");
	pumpUntil(() -> called, 3000);
	Assert.equals(4, got.width);
}

function testHttpImage404GivesNull() {
	var port = TestDriver.startHttpServer("tests/bin/http");
	var called = false, got:ImageInfo = null;
	new HttpImageLoader().load('http://127.0.0.1:$port/missing.png', info -> { called = true; got = info; });
	pumpUntil(() -> called, 3000);
	Assert.isTrue(called);
	Assert.isNull(got);
}

function testHttpImageUnreachableGivesNull() {
	var called = false, got:ImageInfo = null;
	new HttpImageLoader().load("http://127.0.0.1:1/none.png", info -> { called = true; got = info; });
	pumpUntil(() -> called, 5000);
	Assert.isTrue(called);
	Assert.isNull(got);
}

function testHttpImageAfterRemoval() { // Review Focus 6
	var port = TestDriver.startHttpServer("tests/bin/http");
	var image = new Image();
	image.resource = 'http://127.0.0.1:$port/red.png';
	Screen.instance.addComponent(image);
	Screen.instance.removeComponent(image);
	pumpFor(1000); // must not throw
	Assert.pass();
}
```

  `pumpUntil(done, ms)` and `pumpFor(ms)` are private helpers in the case. They call `TestDriver.pump()` in a loop until the condition holds or the time runs out.
- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestImages`
  Expected: FAIL.
  - `testHttpImageLoadsWithoutBlocking` fails because the callback runs inside `load()`.
  - The 404 and unreachable tests crash the run with an uncaught `WebException`.
- [ ] **Step 3: Implement the core `#elseif cs` branch.**
  - Capture the calling thread's event loop (`sys.thread.Thread.current().events`).
  - Fetch on a background thread with `System.Net.Http.HttpClient` (through `cs.Syntax.code`).
  - On any failure (non-2xx, network error, undecodable bytes), deliver `null`.
  - Deliver the result with `events.run(...)`, which is thread-safe and pumped by the desktop host and by `TestDriver.pump`. Delivery calls `Toolkit.assets.imageFromBytes`.
  - No `WebRequest`.
- [ ] **Step 4: Run the case.** Expected: PASS.
- [ ] **Step 5: Run the whole suite and the heaps gate.** Then commit to core-joe and haxeui-cs.
  ```bash
  git -C <haxeui-core-joe> commit -am "HttpImageLoader (cs): load off the UI thread; a failed load gives null, never an exception"
  git add native haxe templates tests && git commit -m "Tests: HTTP images load in the background and fail quietly"
  ```

### Task 6: Components added before the window exists (G5)

**Files:**
- Modify: `native/Host.cs`. `Root` exists before the window, and `CreateWindow` adopts it instead of making a new one.
- Create: `tests/early-add/Main.hx` and `tests/early-add/build.hxml` (headless, `-D haxeui_cs_run`).
- Modify: `README.md` "Testing". Mention the early-add check beside exit-app.

**Interfaces:**
- Consumes: `Host.Root` (unchanged name).

- [ ] **Step 1: Write the failing check.** In `Main.main()`:
  1. `var app = new HaxeUIApp();`.
  2. Make a 100×40 `Box` with `background-color: #FF0000` at (10, 10) and `Screen.instance.addComponent` it before `app.ready`.
  3. In `ready`: `TestDriver.pump(3)`. Print `early-add: ok` and `Host.Exit(0)` if `TestDriver.pixel(50, 30) == 0xFFFF0000`. Otherwise print what was seen and `Host.Exit(1)`.
- [ ] **Step 2: Run it.**
  Run: `haxe tests/early-add/build.hxml`
  Expected: FAIL, with a `NullReferenceException` from `ScreenImpl.addComponent` and a non-zero exit.
- [ ] **Step 3: Implement.** `Host.Root` is created on first use, and `CreateWindow` puts it in the window.
  - If constructing an Avalonia control before `AppBuilder` setup throws, set Avalonia up at first native use instead: headless `SetupWithoutStarting`; desktop, setup first and run the lifetime after. Ledger which one was needed.
- [ ] **Step 4: Run it.**
  Run: `haxe tests/early-add/build.hxml`
  Expected: `early-add: ok`, exit 0. Then `haxe tests/headless.hxml` gives `ALL TESTS OK`, and `haxe tests/exit-app/build.hxml` still exits 0.
- [ ] **Step 5: Commit.**
  ```bash
  git add native/Host.cs tests/early-add README.md
  git commit -m "Components added before the window exists appear when it does"
  ```

### Task 7: Open-folder dialog (G6)

**Files:**
- Modify: `native/FileDialogs.cs`. Add `OpenFolder`, which honours `TestResponse` like the others.
- Modify: `haxe/ui/backend/cs/native/Native.hx`.
- Create: `haxe/ui/backend/OpenFolderDialogImpl.hx`, extending core's `OpenFolderDialogBase`.
- Test: `tests/cases/TestDialogs.hx`.

**Interfaces:**
- Produces: `FileDialogs.OpenFolder(string title, bool multiple, IFileDialogListener listener)`, on `StorageProvider.OpenFolderPickerAsync`.

- [ ] **Step 1: Write the failing tests.**

```haxe
function testOpenFolder() {
	var dir = sys.FileSystem.absolutePath("tests/bin");
	FileDialogs.TestResponse = answer(dir);
	var button:DialogButton = null, folders:Array<String> = null;
	new OpenFolderDialog({title: "Pick"}, (b, f) -> { button = b; folders = f; }).show();
	TestDriver.pump();
	Assert.isTrue(button == DialogButton.OK);
	Assert.equals(dir, folders[0]);
}

function testOpenFolderCancel() {
	FileDialogs.TestResponse = new cs.NativeArray<String>(0);
	var button:DialogButton = null;
	new OpenFolderDialog({}, (b, f) -> button = b).show();
	TestDriver.pump();
	Assert.isTrue(button == DialogButton.CANCEL);
}
```

- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestDialogs`
  Expected: FAIL. Core's stub shows an error box, and the callback never gets OK.
- [ ] **Step 3: Implement** `OpenFolderDialogImpl.show()`: call `FileDialogs.OpenFolder(options.title, options.multiple, new FileDialogListener(dialogConfirmed, dialogCancelled))`.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native/FileDialogs.cs haxe tests/cases/TestDialogs.hx
  git commit -m "OpenFolderDialog through Avalonia's folder picker"
  ```

### Task 8: Layout survives an exception (G7, core-joe)

**Files:**
- Modify (core-joe): `haxe/ui/validation/ValidationManager.hx`, `process()`.
- Modify (core-joe): `haxe/ui/backend/ComponentBase.hx`, `validateComponent`.
- Test: `tests/cases/TestCoreFixes.hx`.

**Interfaces:**
- Consumes: `HeadlessDriver.Pump(frames)`. This drives the real frame loop: `callLater`, then `process()`. **Do not use `TestDriver.pump`**: it calls `process()` directly and would pass on the broken code.

- [ ] **Step 1: Write the failing tests.**

```haxe
function testLayoutContinuesAfterAThrow() {
	var thrower = new Thrower();
	thrower.throwNext = true;
	Screen.instance.addComponent(thrower);
	HeadlessDriver.Pump(3); // the throw is reported on stderr by Host.RunFrame
	var later = new Box();
	later.width = 100;
	later.height = 20;
	Screen.instance.addComponent(later);
	HeadlessDriver.Pump(3);
	Assert.equals(100, later.width);
	Assert.equals(100.0, later.nativePanel.W, "laid out and drawn");
	thrower.invalidateComponentLayout();
	HeadlessDriver.Pump(3);
	Assert.equals(2, thrower.layouts, "the component that threw validates again");
}

function testSpinGuardDropsTheCycle() {
	var a = new Ping(), b = new Ping();
	a.other = b;
	b.other = a;
	Screen.instance.addComponent(a);
	Screen.instance.addComponent(b);
	HeadlessDriver.Pump(5);
	Assert.equals(0, @:privateAccess ValidationManager.instance._queue.length);
}
```

  Two helper classes go in the same file:
  - `Thrower extends Box`: its `validateComponentLayout()` counts `layouts`, and throws once when `throwNext` is set.
  - `Ping extends Box`: its `validateComponentLayout()` calls `other.invalidateComponentLayout()`.
- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestCoreFixes`
  Expected: FAIL. `later.width` stays at 0, and the queue still holds the Pings.
- [ ] **Step 3: Implement, as the spec says.**
  - `process()` restores `isValidating` and `isPending` in a `finally`, so the next `add()` schedules a pass. The exception still propagates.
  - The items after the thrower stay queued.
  - `ComponentBase.validateComponent` resets `_isValidating` in a `finally`.
  - SpinGuard empties `_queue` before it throws.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite and the heaps gate, then commit.**
  ```bash
  git -C <haxeui-core-joe> commit -am "Validation survives a throw: the next invalidation lays out again; SpinGuard drops the cycle"
  git add tests/cases/TestCoreFixes.hx && git commit -m "Tests: layout continues after a component throws"
  ```

### Task 9: Every core module compiles for C# (G8, core-joe)

**Files:**
- Modify (core-joe): `haxe/ui/containers/Collapsible.hx`, `haxe/ui/containers/properties/PropertyGroup.hx` (typed locals for `findComponent` results).
- Modify (core-joe): `haxe/ui/containers/SideBar.hx`. Remove `super.hide()` from the constructor; an `#if cs` branch is allowed.
- Modify: `tests/headless.hxml`. Add `--macro include('haxe.ui.components')` and `--macro include('haxe.ui.containers', true)`.
- Modify: `tools/gallery/gallery.cs.hxml`. Drop the exclusion list.
- Test: `tests/cases/TestCoreFixes.hx`.

- [ ] **Step 1: Write the failing build and tests.** Add the two `include` lines, and:

```haxe
function testCollapsibleSideBarPropertyGrid() {
	var col = new Collapsible();
	col.text = "Section";
	col.addComponent(new Label());
	var grid = new PropertyGrid();
	var group = new PropertyGroup();
	group.text = "Group";
	var prop = new Property();
	prop.label = "Name";
	group.addComponent(prop);
	grid.addComponent(group);
	var bar = new SideBar();
	for (c in ([col, grid, bar] : Array<Component>)) Screen.instance.addComponent(c);
	TestDriver.pump(3);
	Assert.isTrue(col.width > 0 && grid.width > 0);
	col.collapsed = true;
	TestDriver.pump(2);
	Assert.isTrue(col.collapsed);
}
```

- [ ] **Step 2: Run it.**
  Run: `haxe tests/headless.hxml -D test=TestCoreFixes`
  Expected: the C# build fails, with CS1061 errors in `Collapsible.cs` and `PropertyGroup.cs` and CS1511 in `SideBar.cs`.
- [ ] **Step 3: Implement the three core fixes.**
- [ ] **Step 4: Run it.** Expected: the build succeeds and the case passes.
- [ ] **Step 5: Run the whole suite, the gallery's cs build with no exclusions, and the heaps gate. Then commit.**
  ```bash
  git -C <haxeui-core-joe> commit -am "Collapsible, PropertyGroup and SideBar compile for C#"
  git add tests tools/gallery && git commit -m "Suite compiles every core component and container"
  ```

### Task 10: Phase 1 check

- [ ] **Step 1:** Run the gallery and look at every compare page. Any visible difference from html5 that phase 1 caused is fixed now. Expected: none.
- [ ] **Step 2:** Run the Joeditor gate. Expected: `accept: OK`.
- [ ] **Step 3:** Run `haxe tests/headless.hxml`, `haxe tests/exit-app/build.hxml` and `haxe tests/early-add/build.hxml`. Expected: all exit 0.

---

## Phase 2: what Joeditor needs

### Task 11: Font files (G9)

**Files:**
- Create: `native/UIFonts.cs`.
- Modify: `native/UIText.cs`, `native/UITextInput.cs`. `SetFont` accepts the family strings `UIFonts` returns.
- Modify: `haxe/ui/backend/AssetsImpl.hx`:
  - `getFontInternal` takes file paths ending `.ttf`/`.otf`;
  - it adds a `getFontFromHaxeResource` override.
- Modify: `haxe/ui/backend/FontData.hx` (doc comment only: FontData is an Avalonia family reference).
- Modify: `haxe/ui/backend/cs/native/Native.hx`.
- Create: `tests/assets/DejaVuSansMono.ttf`, copied from `<JoeClash>/lib/epubreader/tools/fonts-src/`. Copy its licence file too if one sits beside it.
- Modify: `tests/headless.hxml`. Add `--resource tests/assets/DejaVuSansMono.ttf@fonts/DejaVuSansMono.ttf`.
- Create: `tests/cases/TestFonts.hx`, registered in `TestMain`.

**Interfaces:**
- Produces:
  - `UIFonts.FromBytes(string key, byte[] data): string` returns a family reference for `new FontFamily(...)`, or null when the bytes are not a font. It goes through a font collection registered once with `FontManager.Current.AddFontCollection`, using `FontCollectionBase.TryAddGlyphTypeface(Stream, out GlyphTypeface)`.
  - `UIFonts.FromFile(string path): string` returns null when the file is missing or isn't a font.
  - `UIFonts.ResolveFamily(string name): string` is used by `SetFont`. Task 22 extends it.

- [ ] **Step 1: Write the failing tests.** `width(text, style)` is a private helper. It adds a Label with that `styleString` and text, pumps 3 frames, and returns `label.width`.

```haxe
function testFontFromResource() {
	var s = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
	Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
	Assert.isTrue(width("WWWWWWWW", "font-size: 20px;") - width("iiiiiiii", "font-size: 20px;") > 20, "default font is proportional");
}

function testFontFromRelativePath() {
	var s = "font-name: tests/assets/DejaVuSansMono.ttf; font-size: 20px;";
	Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
}

function testFontFromAbsolutePath() {
	var p = StringTools.replace(sys.FileSystem.absolutePath("tests/assets/DejaVuSansMono.ttf"), "\\", "/");
	var s = 'font-name: "$p"; font-size: 20px;';
	Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
}

function testBoldStillApplies() {
	var s = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
	Assert.isTrue(width("WWWW", s + " font-bold: true;") >= width("WWWW", s));
}

function testMissingFontFallsBack() { // Review Focus 2
	Assert.isTrue(width("Hello", "font-name: nowhere/missing.ttf;") > 0);
}

function testNotAFontFallsBack() { // Review Focus 2: a PNG named as a font
	Assert.isTrue(width("Hello", "font-name: red4x4.png;") > 0);
}

function testTextInputUsesFont() {
	var f = new TextField();
	f.styleString = "font-name: fonts/DejaVuSansMono.ttf; font-size: 20px;";
	f.text = "iiiiiiii";
	Screen.instance.addComponent(f);
	TestDriver.pump(3);
	var narrow = f.getTextInput().textWidth;
	f.text = "WWWWWWWW";
	TestDriver.pump(3);
	Assert.floatEquals(narrow, f.getTextInput().textWidth, 1.0);
}
```

- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestFonts`
  Expected: the three monospace tests FAIL (the text is in the default proportional font). The fallback tests pass already.
- [ ] **Step 3: Implement `UIFonts`, and the `AssetsImpl` routing.**
  - A Haxe resource goes through `getFontFromHaxeResource`, then `UIFonts.FromBytes(resourceId, bytes)`.
  - A path ending `.ttf`/`.otf`, relative or absolute, goes through `UIFonts.FromFile`.
  - A null result means `callback(null)`: the default family.
  - Plain names keep today's behaviour.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native haxe tests
  git commit -m "Font files: font-name may name a .ttf/.otf resource or file"
  ```

### Task 12: Box shadows (G10)

Shadows follow html5's maths exactly (`haxe/ui/backend/html5/FilterHelper.hx`). All of them shadow the component's background box.

**Files:**
- Modify: `native/UIStyle.cs`. Add `ClearShadows()`, `AddShadow(...)` and a `BoxShadows Shadows` field.
- Modify: `native/UIPanel.cs`, `UIPainter.RenderStyle`. Draw the rounded background with `DrawRectangle(brush, pen, roundedRect, Shadows)`. The shadows draw even when the background brush is null.
- Modify: `haxe/ui/backend/cs/StyleMapper.hx`. Map `style.filter`'s `DropShadow` and `BoxShadow` entries.
- Modify: `haxe/ui/backend/cs/native/Native.hx`.
- Create: `tests/cases/TestFilters.hx`, registered in `TestMain`.
- Create: `tests/cases/Pixels.hx`, static test helpers, starting with `bright(argb:Int):Int` (R+G+B).

**Interfaces:**
- Produces:
  - `Pixels.bright(argb):Int`, which Task 13 extends.
  - `UIStyle.ClearShadows(): void`.
  - `UIStyle.AddShadow(double offsetX, double offsetY, double blur, double spread, uint argb, bool inset): void`. The alpha is in `argb`'s top byte: `round(alpha * 255)`.
- The mapping:
  - `DropShadow` with `inner=false`: offset (`distance`, `distance + 2`), blur `blurX - 1`, spread `blurY - 1`.
  - `DropShadow` with `inner=true`: inset, offset (`distance`, `distance`), blur `blurX`, spread 0.
  - `BoxShadow`: (`offsetX`, `offsetY`, `blurRadius`, `spreadRadius`, `inset`) as written.
  - Negative blur and spread clamp to 0.

- [ ] **Step 1: Write the failing tests.** `box(style)` adds a white 100×60 Box at (20, 20) with `border-size: 0px; padding: 0px; background-color: #FFFFFF;` plus `style`, and pumps 3 frames. `bright` is `Pixels.bright`, imported statically.

```haxe
function testDropShadowOffsetsDownRight() {
	box("filter: drop-shadow(4, 45, #000000, 0.5, 1, 1, 1, 1, false);");
	Assert.isTrue(bright(TestDriver.pixel(122, 84)) < 520, "inside the shadow, outside the box");
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(16, 50), "no shadow on the left");
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(122, 23), "the shadow starts 6px down");
}

function testInnerDropShadow() {
	box("filter: drop-shadow(4, 45, #000000, 0.8, 2, 1, 1, 1, true);");
	Assert.isTrue(bright(TestDriver.pixel(22, 22)) < bright(TestDriver.pixel(70, 50)));
}

function testBoxShadowAsWritten() {
	box("filter: box-shadow(-6, 0, #000000, 0.5, 0, 0, false);");
	Assert.isTrue(bright(TestDriver.pixel(16, 50)) < 520);
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(123, 50));
}

function testShadowClears() { // Review Focus 1
	var b = box("filter: box-shadow(-6, 0, #000000, 0.5, 0, 0, false);");
	b.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; filter: none;";
	TestDriver.pump(3);
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(16, 50));
}

function testThemePopupHasAShadow() {
	var b = box("");
	b.addClass("popup");
	TestDriver.pump(3);
	Assert.isTrue(bright(TestDriver.pixel(70, 83)) < 765, "the theme's .popup drop-shadow shows below the box");
}
```

- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestFilters`
  Expected: FAIL. No shadows are drawn.
- [ ] **Step 3: Implement** `AddShadow`/`ClearShadows`, the painter call, and the `StyleMapper` mapping above.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native haxe tests
  git commit -m "Shadows: drop-shadow and box-shadow, inset too, with html5's numbers"
  ```

### Task 13: The text-shadow directive (G11)

**Files:**
- Create: `haxe/ui/backend/cs/directives/TextShadow.hx`.
  - Class `TextShadow extends haxe.ui.styles.DirectiveHandler`. Its `apply` is empty: the class exists so that core keeps the directive.
  - Plus `public static function parse(value:haxe.ui.styles.Value):Null<{dx:Float, dy:Float, blur:Float, argb:UInt}>`.
- Modify: `haxe/ui/backend/module.xml`. Register `<cssDirective name="text-shadow" class="haxe.ui.backend.cs.directives.TextShadow" />`, following html5's module.xml structure.
- Modify: `haxe/ui/backend/TextDisplayImpl.hx`, `validateStyle`. It reads `_textStyle.customDirectives.get("text-shadow")`, applies on change, and clears on `none` or absence.
- Modify: `native/UIText.cs`, `native/UITextInput.cs`. Add `SetShadow`, using `DropShadowEffect` (OffsetX, OffsetY, BlurRadius, Color, Opacity).
- Modify: `native/TestDriver.cs`, `haxe/ui/backend/cs/TestDriver.hx`, `Native.hx`. Add the region read.
- Modify: `tests/cases/Pixels.hx`. Add `countWhere` and `longestRun`.
- Test: `tests/cases/TestFilters.hx`.

**Interfaces:**
- Produces:
  - `UIText.SetShadow(double dx, double dy, double blur, uint argb)`; `argb == 0` clears it. `UITextInput.SetShadow` is the same.
  - Syntax: `text-shadow: <dx>px <dy>px <blur>px <#rrggbb> [<alpha 0..1>]`, alpha defaulting to 1.
  - `HeadlessDriver.PixelsAt(int x, int y, int w, int h): int[]` takes one capture and returns row-major ARGB. Haxe: `TestDriver.pixels(x, y, w, h):Array<Int>`.
  - `Pixels.bright(argb):Int`.
  - `Pixels.countWhere(pixels:Array<Int>, test:Int->Bool):Int`.
  - `Pixels.longestRun(pixels:Array<Int>, width:Int, row:Int, test:Int->Bool):Int`.
- Used by Tasks 16–19, 23, 31 and 32.

- [ ] **Step 1: Write the failing tests.** `whiteLabel(style)` adds a Label at (10, 10) with text "MMMM", `font-size: 24px; color: #FFFFFF;` plus `style`, and pumps 3 frames. White glyphs on the white window are invisible, so every dark pixel is shadow.

```haxe
function testTextShadowDrawsBehindGlyphs() {
	var l = whiteLabel("text-shadow: 2px 2px 0px #000000;");
	var px = TestDriver.pixels(10, 10, Std.int(l.width) + 4, Std.int(l.height) + 4);
	Assert.isTrue(Pixels.countWhere(px, p -> Pixels.bright(p) < 200) > 20);
}

function testTextShadowAlpha() {
	var l = whiteLabel("text-shadow: 2px 2px 0px #000000 0.5;");
	var px = TestDriver.pixels(10, 10, Std.int(l.width) + 4, Std.int(l.height) + 4);
	Assert.equals(0, Pixels.countWhere(px, p -> Pixels.bright(p) < 250), "half-alpha black is never near-black");
	Assert.isTrue(Pixels.countWhere(px, p -> Pixels.bright(p) < 520) > 20);
}

function testTextShadowNone() {
	var l = whiteLabel("text-shadow: 2px 2px 0px #000000;");
	l.styleString = "font-size: 24px; color: #FFFFFF; text-shadow: none;";
	TestDriver.pump(3);
	var px = TestDriver.pixels(10, 10, Std.int(l.width) + 4, Std.int(l.height) + 4);
	Assert.equals(0, Pixels.countWhere(px, p -> Pixels.bright(p) < 700));
}

function testShadowSetBeforeText() { // Review Focus 4
	var l = new Label();
	l.left = 10;
	l.top = 10;
	l.styleString = "font-size: 24px; color: #FFFFFF; text-shadow: 2px 2px 0px #000000;";
	Screen.instance.addComponent(l);
	TestDriver.pump(2);
	l.text = "MMMM";
	TestDriver.pump(3);
	var px = TestDriver.pixels(10, 10, Std.int(l.width) + 4, Std.int(l.height) + 4);
	Assert.isTrue(Pixels.countWhere(px, p -> Pixels.bright(p) < 200) > 20);
}
```

- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestFilters`
  Expected: FAIL. The three shadow-present tests find no dark pixels.
- [ ] **Step 3: Implement** the directive class, its registration, `parse`, `TextDisplayImpl` reading it, `SetShadow`, and `PixelsAt`.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native haxe tests
  git commit -m "text-shadow: a haxeui-cs directive that shadows the glyphs"
  ```

### Task 14: Blur (G12)

**Files:**
- Modify: `native/UIStyle.cs`. Add `public double Blur;` (0 = none).
- Modify: `native/UIPanel.cs`, `ApplyStyle`. `Effect = Blur > 0 ? new BlurEffect { Radius = ... } : null` on the panel itself, so it covers the whole subtree, as CSS `filter` does.
- Modify: `haxe/ui/backend/cs/StyleMapper.hx`. Map the `Blur` filter's `amount`.
- Modify: `haxe/ui/backend/cs/native/Native.hx`.
- Test: `tests/cases/TestFilters.hx`.

- [ ] **Step 1: Write the failing tests.** `edge(style)` adds a white 100×60 Box at (20, 20). It has a black 10×60 child Box at child-left 45, plus `style` on the parent, and pumps 3 frames.

```haxe
function testBlurSoftensEdges() {
	edge("filter: blur(4);");
	var b = Pixels.bright(TestDriver.pixel(20 + 42, 50));
	Assert.isTrue(b > 60 && b < 720, 'grey expected, got $b');
}

function testBlurClears() { // Review Focus 1
	var parent = edge("filter: blur(4);");
	parent.styleString = "border-size: 0px; padding: 0px; background-color: #FFFFFF; filter: none;";
	TestDriver.pump(3);
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(20 + 42, 50));
}
```

- [ ] **Step 2: Run them.** Expected: FAIL. The pixel stays pure white.
- [ ] **Step 3: Implement.** The CSS `blur(n)` radius to Avalonia `BlurEffect.Radius` scaling is the builder's call; match html5 by eye in the gallery's blur sample.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Run the whole suite, then commit.**
  ```bash
  git add native haxe tests
  git commit -m "filter: blur on a component and everything in it"
  ```

### Task 15: Phase 2 check

- [ ] **Step 1:** Run the gallery.
  - The shadow, inner-shadow and blur samples, the theme's menus, dialogs and windows, and pressed buttons now match html5.
  - Fix any difference now, or ledger it as a ruling.
- [ ] **Step 2:** Run the Joeditor gate. Expected: `accept: OK`.
- [ ] **Step 3: The one-off Joeditor check** (spec "Verification"). It is uncommitted, and is reverted with `git -C <JoeClash-gate> checkout -- .` afterwards.
  1. In the gate worktree, add `font-name: GameFont.ttf` (the path `res/GameFont.ttf`) to the editor stylesheet's root style.
  2. In `MapView.shadow`'s `#if haxeui_cs` branch, set the label's `styleString` to add `text-shadow: 1px 1px 0px #000000 0.9`.
  3. Build with `-D haxeui_cs_headless` and run `--cs-shot`.
  4. Look at the picture: the text is in GameFont, and the map names have a dark edge.
  5. Revert.

---

## Phase 3: the rest of parity

### Task 16: Per-side borders follow the radius (G13)

**Files:**
- Modify: `native/UIPanel.cs`, `UIPainter.RenderBorder`, the non-uniform path.
  1. Build the border ring: the outer `RoundedRect` geometry excluding the inner one. The inner radii are each outer radius minus the adjoining side widths, clamped at 0.
  2. Fill each side's brush clipped to that side's trapezoid, from the outer corners to the inner corners.
- Test: `tests/cases/TestStyles.hx`.

- [ ] **Step 1: Write the failing test.**

```haxe
function testPerSideBorderFollowsRadius() {
	show("background-color: #FFFFFF; border-radius: 12px; border-top-size: 4px; border-top-color: #FF0000;"
		+ " border-bottom-size: 4px; border-bottom-color: #0000FF; border-left-size: 1px; border-left-color: #000000;");
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(1, 1), "outside the rounded corner");
	Assert.equals(0xFFFF0000, TestDriver.pixel(50, 1), "top side");
	Assert.equals(0xFF0000FF, TestDriver.pixel(50, 58), "bottom side");
	Assert.equals(0xFF000000, TestDriver.pixel(0, 30), "left side");
}
```

- [ ] **Step 2: Run it.** Expected: FAIL at "outside the rounded corner", which is red today.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it, then the whole suite.** Expected: PASS, and `testBorderPerSide` still passes.
- [ ] **Step 5: Commit.**
  ```bash
  git add native/UIPanel.cs tests/cases/TestStyles.hx
  git commit -m "Per-side borders follow the border radius"
  ```

### Task 17: Dashed and dotted borders (G14)

**Files:**
- Modify: `native/UIStyle.cs`. Add `public int BorderStyle;`: 0 solid, 1 dashed, 2 dotted.
- Modify: `native/UIPanel.cs`. A uniform border uses a `Pen` with `DashStyle`: dashes 3×width with gaps 3×width, dots 1×width with gaps 1×width, round caps for dotted. Per-side borders are stroked along each side's centre line with the same dash.
- Modify: `haxe/ui/backend/cs/StyleMapper.hx` (`style.borderStyle`), `Native.hx`.
- Test: `tests/cases/TestStyles.hx`.

- [ ] **Step 1: Write the failing tests.**

```haxe
function testDashedBorderHasGaps() {
	show("background-color: #FFFFFF; border: 2px dashed #000000;");
	var row = TestDriver.pixels(4, 1, 92, 1);
	Assert.isTrue(Pixels.countWhere(row, p -> p == 0xFF000000) > 10);
	Assert.isTrue(Pixels.countWhere(row, p -> Pixels.bright(p) > 700) > 10);
}

function testDottedPerSideBorder() {
	show("background-color: #FFFFFF; border-left-size: 2px; border-left-color: #000000; border-style: dotted;");
	var col = TestDriver.pixels(1, 4, 1, 52);
	Assert.isTrue(Pixels.countWhere(col, p -> Pixels.bright(p) > 700) > 10);
}

function testSolidBorderHasNoGaps() {
	show("background-color: #FFFFFF; border: 2px solid #000000;");
	Assert.equals(0, Pixels.countWhere(TestDriver.pixels(4, 1, 92, 1), p -> Pixels.bright(p) > 700));
}
```

- [ ] **Step 2: Run them.** Expected: the dashed and dotted tests FAIL; the solid test passes.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests/cases/TestStyles.hx
  git commit -m "border-style: dashed and dotted"
  ```

### Task 18: Strikethrough, and underline in text inputs (G15)

**Files:**
- Modify: `native/UIText.cs`, `native/UITextInput.cs`.
  - `SetFont` gains a `strikethrough` parameter and sets `TextDecorations` to underline, strikethrough or both.
  - `UITextInput.SetFont` stops ignoring `underline`.
- Modify: `haxe/ui/backend/TextDisplayImpl.hx`, `TextInputImpl.hx`, `Native.hx`. `fontStrikeThrough` joins the font key and goes through `applyFont`.
- Test: `tests/cases/TestText.hx`.

**Interfaces:**
- Produces: `SetFont(string family, double size, bool bold, bool italic, bool underline, bool strikethrough)` on both natives.

- [ ] **Step 1: Write the failing tests.** `darkRun(c)` scans every row of the component's rectangle and returns the longest run of pixels with `bright < 300`, using `Pixels.longestRun`. The text is "oooooo", 30 px, black: it has no horizontal strokes of its own.

```haxe
function testStrikeThrough() {
	var plain = label("oooooo", "font-size: 30px; color: #000000;");
	var struck = label("oooooo", "font-size: 30px; color: #000000; text-decoration: line-through;");
	Assert.isTrue(darkRun(struck) > 0.8 * struck.width);
	Assert.isTrue(darkRun(plain) < 0.5 * plain.width);
}

function testTextInputUnderline() {
	var f = new TextField();
	f.styleString = "font-size: 30px; color: #000000; font-underline: true; border-size: 0px; background-color: #FFFFFF;";
	f.text = "oooooo";
	Screen.instance.addComponent(f);
	TestDriver.pump(3);
	Assert.isTrue(darkRun(f) > 0.6 * f.getTextInput().textWidth);
}
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests/cases/TestText.hx
  git commit -m "Strikethrough, and underline in text inputs"
  ```

### Task 19: Justified text (G16)

**Files:**
- Modify: `native/UIText.cs`, `UITextInput.cs`. `SetAlign` value 3 is `TextAlignment.Justify`.
- Modify: `haxe/ui/backend/TextDisplayImpl.hx`. `"justify"` maps to 3.
- Test: `tests/cases/TestText.hx`.

- [ ] **Step 1: Write the failing test.** A 200-px-wide wrapping Label holds "aa bb cc dd ee ff gg hh ii jj kk ll mm nn oo pp" at 13 px with `text-align: justify`. In the first line's rows (the top 14 px), the rightmost pixel with `bright < 500` is at x ≥ label.left + 196.
- [ ] **Step 2: Run it.** Expected: FAIL. The text is left-aligned, with a ragged right edge.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests/cases/TestText.hx
  git commit -m "text-align: justify"
  ```

### Task 20: Backgrounds (G17)

There are four parts, each with its own red/green cycle. One commit at the end.

**Files:**
- Modify: `native/UIStyle.cs`:
  - `BgWidth`, `BgHeight` (px, NaN unset);
  - `BgWidthPercent`, `BgHeightPercent` (NaN unset);
  - `public bool SliceRepeat;`;
  - `public bool Pixelated;`.
- Modify: `native/UIPanel.cs`, `RenderBackgroundImage`:
  - honour the size for repeat and natural modes;
  - tile 9-slice edges and centre when `SliceRepeat`;
  - clip the image to the background's `RoundedRect`;
  - use `BitmapInterpolationMode.None` when `Pixelated`, through `RenderOptions`.
- Modify: `native/UIImage.cs`, `UIImageView`. Add `SetPixelated(bool)`.
- Modify: `haxe/ui/backend/cs/StyleMapper.hx`:
  - `backgroundWidth(Percent)` and `backgroundHeight(Percent)`;
  - `SliceRepeat` when `backgroundImageRepeat == "repeat"` with a slice;
  - `imageRendering == "pixelated"`.
- Modify: `haxe/ui/backend/ImageDisplayImpl.hx`. Image components follow `image-rendering` too.
- Modify: `Native.hx`.
- Create, with Python and PIL:
  - `tests/assets/checker2x2.png`: black, white / white, black;
  - `tests/assets/slice9-pattern.png`: 12×12, the same corners and edges as `slice9.png` (blue corners, green edges), but the centre column x 4..7 holds red at x 4–5 and yellow (`#FFFF00`) at x 6–7.
  Add both as `--resource` lines in `tests/headless.hxml`.
- Test: `tests/cases/TestImages.hx`.

- [ ] **Step 1: Write the four failing tests.**

```haxe
function testBackgroundSize() {
	var b = box100x60('background-image: "red4x4.png"; background-image-repeat: no-repeat; background-width: 20px; background-height: 10px;');
	Assert.equals(0xFFFF0000, TestDriver.pixel(15, 5));
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(25, 5));
	b.styleString = 'border-size: 0px; padding: 0px; background-image: "red4x4.png"; background-image-repeat: no-repeat; background-width: 50%; background-height: 10px;';
	TestDriver.pump(3);
	Assert.equals(0xFFFF0000, TestDriver.pixel(45, 5));
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(55, 5));
}

function testBackgroundImageClippedToRadius() {
	box100x60('background-image: "red4x4.png"; border-radius: 20px;');
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(1, 1));
	Assert.equals(0xFFFF0000, TestDriver.pixel(50, 30));
}

function testNineSliceRepeatTilesTheCentre() {
	var b = box100x60('background-image: "slice9-pattern.png"; background-image-repeat: repeat; '
		+ 'background-image-slice-left: 4px; background-image-slice-top: 4px; background-image-slice-right: 8px; background-image-slice-bottom: 8px;');
	b.width = 200;
	TestDriver.pump(3);
	Assert.equals(0xFFFF0000, TestDriver.pixel(4 + 40 + 1, 30), "a red stripe 40px in");
	Assert.equals(0xFFFFFF00, TestDriver.pixel(4 + 40 + 3, 30), "then yellow: tiled every 4px, not stretched");
}

function testPixelatedImage() {
	var img = new Image();
	img.resource = "checker2x2.png";
	img.width = 40;
	img.height = 40;
	img.styleString = "image-rendering: pixelated;";
	Screen.instance.addComponent(img);
	TestDriver.pump(3);
	var p = TestDriver.pixel(19, 5);
	Assert.isTrue(p == 0xFF000000 || p == 0xFFFFFFFF, 'no interpolated grey at the cell edge: ${StringTools.hex(p, 8)}');
}
```

  `box100x60(style)` adds a 100×60 Box at (0, 0) with `border-size: 0px; padding: 0px;` plus `style`, and pumps 3 frames.
- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestImages`
  Expected: all four FAIL.
- [ ] **Step 3: Implement** the four features, re-running the case after each, until all four pass.
- [ ] **Step 4: Run the whole suite.** Expected: `ALL TESTS OK`. The existing `slice9` test still passes.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "Backgrounds: size, 9-slice repeat, clipped to the radius, pixelated images"
  ```

### Task 21: Cursors (G18)

**Files:**
- Modify: `native/UIStyle.cs`. `CursorFor` uses a table.
  - CSS names to `StandardCursorType`:
    - `pointer`→Hand, `text`→Ibeam, `move`→SizeAll, `default`→Arrow, `none`→None;
    - `not-allowed`→No, `wait`→Wait, `progress`→AppStarting, `crosshair`→Cross, `help`→Help;
    - `grab`→Hand, `grabbing`→DragMove;
    - `col-resize`/`ew-resize`→SizeWestEast, `row-resize`/`ns-resize`→SizeNorthSouth;
    - `nwse-resize`→TopLeftCorner, `nesw-resize`→TopRightCorner;
    - `n-resize`→TopSide, `s-resize`→BottomSide, `e-resize`→RightSide, `w-resize`→LeftSide.
  - Add `public static string StandardCursorName(string css)`, which returns the enum name or null.
- Modify: `native/UIPanel.cs`.
  - `public string CursorName { get; }` is the effective CSS cursor, null while suppressed.
  - `SetCursorSuppressed(bool)` drops the cursor while a component is disabled.
- Modify: `native/Host.cs`. Add `SetScreenCursor(string css)`, where null clears, and `ScreenCursorName`. It sets the window's cursor.
- Create: `haxe/ui/backend/cs/ScreenCursor.hx`, with `set(name:String)` and `clear()`.
- Modify: `haxe/ui/backend/ComponentImpl.hx`. Override `handleDisabled(disable:Bool)` to call `nativePanel.SetCursorSuppressed(disable)`.
- Modify (core-joe): `containers/Splitter.hx:139`, `HorizontalSplitter.hx:23`, `VerticalSplitter.hx:23`, `windows/Window.hx:455,532`. Next to each `#if haxeui_html5` body-cursor line, add `#elseif haxeui_cs` calling `haxe.ui.backend.cs.ScreenCursor.set(...)` or `.clear()`.
- Modify: `Native.hx`.
- Create: `tests/cases/TestCursors.hx`, registered in `TestMain`.

- [ ] **Step 1: Write the failing tests.**

```haxe
function testCssCursorNames() {
	var expected = ["pointer" => "Hand", "none" => "None", "not-allowed" => "No", "wait" => "Wait", "crosshair" => "Cross",
		"help" => "Help", "nwse-resize" => "TopLeftCorner", "nesw-resize" => "TopRightCorner", "ns-resize" => "SizeNorthSouth",
		"ew-resize" => "SizeWestEast", "grabbing" => "DragMove"];
	for (css => name in expected) Assert.equals(name, UIStyle.StandardCursorName(css), css);
}

function testDisabledComponentDropsCursor() {
	var b = new Button();
	b.text = "x";
	Screen.instance.addComponent(b);
	TestDriver.pump(2);
	Assert.equals("pointer", b.nativePanel.CursorName);
	b.disabled = true;
	TestDriver.pump(2);
	Assert.isNull(b.nativePanel.CursorName);
}

function testSplitterDragHoldsScreenCursor() {
	var s = new HorizontalSplitter();
	s.width = 300;
	s.height = 100;
	for (i in 0...2) { var bx = new Box(); bx.percentWidth = 50; bx.percentHeight = 100; s.addComponent(bx); }
	Screen.instance.addComponent(s);
	TestDriver.pump(3);
	var grip = s.findComponent(SplitterGripper, true);
	var p = TestDriver.centerOf(grip);
	TestDriver.mouseMove(p.x, p.y);
	TestDriver.mouseDown(p.x, p.y);
	TestDriver.pump();
	TestDriver.mouseMove(p.x + 20, p.y);
	TestDriver.pump();
	Assert.equals("col-resize", Host.ScreenCursorName);
	TestDriver.mouseUp(p.x + 20, p.y);
	TestDriver.pump();
	Assert.isNull(Host.ScreenCursorName);
}
```

  The gripper class is whatever `HorizontalSplitter` adds between its children; find its real name in core.
- [ ] **Step 2: Run them.** Expected: FAIL. `StandardCursorName` does not exist, so the build fails; that counts.
- [ ] **Step 3: Implement**, including the core `#elseif haxeui_cs` lines.
- [ ] **Step 4: Run them, the whole suite and the heaps gate.** Expected: PASS.
- [ ] **Step 5: Commit both repos.**
  ```bash
  git -C <haxeui-core-joe> commit -am "Splitter and Window drags hold the screen cursor on haxeui-cs too"
  git add native haxe tests && git commit -m "Cursors: every CSS name Avalonia can show; disabled drops it; drags hold it"
  ```

### Task 22: Generic font families (G19)

**Files:**
- Modify: `native/UIFonts.cs`, `ResolveFamily`.
  - `monospace`: Windows `Consolas`, macOS `Menlo`, Linux `DejaVu Sans Mono`.
  - `serif`: Windows `Times New Roman`, macOS `Times`, Linux `DejaVu Serif`.
  - `cursive`: Windows `Comic Sans MS`, macOS `Apple Chancery`, Linux the default.
  - `sans-serif` and `system-ui`: the default family.
  - Each falls back to the default family if the named font is not installed.
- Test: `tests/cases/TestFonts.hx`.

- [ ] **Step 1: Write the failing test.**

```haxe
function testGenericMonospace() {
	var s = "font-name: monospace; font-size: 20px;";
	Assert.floatEquals(width("iiiiiiii", s), width("WWWWWWWW", s), 1.0);
}
```

- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native/UIFonts.cs tests/cases/TestFonts.hx
  git commit -m "Generic font families: monospace, serif, cursive, sans-serif, system-ui"
  ```

### Task 23: Colour filters (G20)

Avalonia 12 has no colour-matrix effect for a subtree. Colours and bitmaps are mapped at paint time: each painted thing under a filtered panel maps its own colours and pixels through the effective matrix.

**Files:**
- Create: `native/ColorMatrix.cs`.
  - `ColorMatrix.Apply(float[] m, uint argb): uint`.
  - `ColorMatrix.Compose(float[] outer, float[] inner): float[]`.
  - `ColorMatrix.Filter(UIImage image, float[] m): UIImage`, cached per image and matrix.
  - The matrices are 4×5 row-major, as SVG's `feColorMatrix`, with offsets in 0..1.
- Modify: `native/UIPanel.cs`.
  - `SetColorMatrix(float[] own)` takes null for none.
  - The effective matrix is the parent's composed with the panel's own. It is passed down to child panels and to content through `IColorFiltered`.
- Modify: `native/UIPanel.cs` (UIPainter brushes), `UIText.cs`, `UITextInput.cs`, `UIImage.cs` (`UIImageView`) and `UIGraphics.cs`. Each implements `IColorFiltered { void SetEffectiveColorMatrix(float[] m); }` and maps its colours and bitmaps.
- Create: `haxe/ui/backend/cs/ColorFilters.hx`.
  - `ColorFilters.matrixFor(filters:Array<Filter>):cs.NativeArray<Single>` returns null when there are no colour filters.
  - It covers grayscale(`amount`%), tint(`color`, `amount`), brightness(`multiplier`), contrast(`multiplier`), saturate(`multiplier`), hue-rotate(`angleDegree`) and invert(`multiplier`).
  - It uses the CSS Filter Effects formulas, in the order given; tint copies `FilterHelper.tintToSvg`.
- Modify: `haxe/ui/backend/cs/StyleMapper.hx` and `ComponentImpl.hx`, which call `nativePanel.SetColorMatrix`.
- Modify: `Native.hx`.
- Test: `tests/cases/TestFilters.hx`.

- [ ] **Step 1: Write the failing tests.** Three private helpers:
  - `solid(colour, filter)` adds a 60×40 Box at (20, 20) with that background and `filter`, pumps 3 frames, and returns the pixel at (40, 40).
  - `near(a, b, tol)` compares each channel within `tol`.
  - `gray(p)` is the opaque grey whose three channels all equal p's channel average.

```haxe
function testGrayscale() { var p = solid("#FF0000", "grayscale"); Assert.isTrue(near(p, gray(p), 3)); }
function testBrightnessHalves() { Assert.isTrue(near(solid("#C86432", "brightness(0.5)"), 0xFF643219, 2)); }
function testInvert() { Assert.isTrue(near(solid("#FF0000", "invert(1)"), 0xFF00FFFF, 2)); }
function testSaturateZeroIsGray() { var p = solid("#3366CC", "saturate(0)"); Assert.isTrue(near(p, gray(p), 3)); }
function testContrastZeroIsMidGray() { Assert.isTrue(near(solid("#3366CC", "contrast(0)"), 0xFF808080, 3)); }
function testHueRotate180TurnsRedTowardsCyan() {
	var p = solid("#FF0000", "hue-rotate(180)");
	Assert.isTrue(((p >> 16) & 0xFF) < ((p >> 8) & 0xFF) && ((p >> 16) & 0xFF) < (p & 0xFF));
}
function testTint() { Assert.isTrue(near(solid("#FFFFFF", "tint(#FF0000, 1)"), 0xFFFF0000, 6)); }

function testFilterReachesChildren() {
	var parent = new Box(); parent.left = 20; parent.top = 20; parent.width = 60; parent.height = 40;
	parent.styleString = "filter: grayscale;";
	var child = new Box(); child.percentWidth = 100; child.percentHeight = 100;
	child.styleString = "background-color: #FF0000;";
	parent.addComponent(child);
	Screen.instance.addComponent(parent);
	TestDriver.pump(3);
	var p = TestDriver.pixel(40, 40);
	Assert.isTrue(near(p, gray(p), 3));
}

function testFilterReachesImageAndCanvas() { // Review Focus 5
	// a grayscale parent holding an Image of red4x4.png and a Canvas with a red rectangle:
	// a pixel from each is grey
}

function testColourFilterClears() { // Review Focus 1: the filter set, then filter: none; the pixel is red again
}

function testDisabledImageIsGray() { // the default theme: .image:disabled { filter: grayscale }
	// an Image of red4x4.png at 40x40 with disabled = true; its pixel is grey
}
```

  The three tests given as comments are written out in the same style as the ones above.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** `ColorMatrix.cs`, the propagation, each painter, and `ColorFilters.hx`.
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "Colour filters: grayscale, tint, brightness, contrast, saturate, hue-rotate, invert"
  ```

### Task 24: Toolkit.scale (G21)

As heaps does it: each root component is scaled when it is added, the screen size is divided by the scale, and pointer positions are divided too.

**Files:**
- Modify: `native/UIPanel.cs`. Add `SetScale(double sx, double sy)`: a `ScaleTransform` render transform with origin (0, 0).
- Modify: `haxe/ui/backend/ScreenImpl.hx`.
  - `addComponent` calls `component.nativePanel.SetScale(Toolkit.scaleX, Toolkit.scaleY)`.
  - `get_width` and `get_height` divide by `Toolkit.scaleX` and `Toolkit.scaleY`.
- Modify: `haxe/ui/backend/cs/InputListener.hx`. `screenX` and `screenY` divide by `Toolkit.scaleX` and `Toolkit.scaleY`.
- Modify: `Native.hx`.
- Create: `tests/cases/TestScale.hx`, registered in `TestMain`. Its teardown sets `Toolkit.scale = 1` and removes every root component.

- [ ] **Step 1: Write the failing tests.**

```haxe
function testScreenSizeDivides() {
	Toolkit.scale = 2;
	Assert.floatEquals(Host.ClientWidth / 2, Screen.instance.width);
}

function testRootDrawsScaled() {
	Toolkit.scale = 2;
	var b = redBox(10, 10, 50, 30);
	Assert.equals(0xFFFF0000, TestDriver.pixel(25, 25));
	Assert.equals(0xFFFF0000, TestDriver.pixel(115, 75));
	Assert.equals(0xFFFFFFFF, TestDriver.pixel(125, 30));
}

function testClickInHaxeUIUnits() {
	Toolkit.scale = 2;
	var b = redBox(10, 10, 50, 30);
	var at:MouseEvent = null;
	b.registerEvent(MouseEvent.CLICK, e -> at = e);
	TestDriver.click(100, 50);
	Assert.floatEquals(50, at.screenX);
	Assert.floatEquals(25, at.screenY);
}

function testPopupIsScaled() { // Review Focus 3
	Toolkit.scale = 2;
	var dd = new DropDown();
	dd.dataSource = ArrayDataSource.fromArray([{text: "One"}, {text: "Two"}]);
	Screen.instance.addComponent(dd);
	TestDriver.pump(3);
	TestDriver.click(dd.screenLeft * 2 + 10, dd.screenTop * 2 + 10);
	TestDriver.pump(3);
	var popup = Screen.instance.rootComponents[Screen.instance.rootComponents.length - 1];
	Assert.isTrue(popup != dd);
	Assert.floatEquals(popup.screenTop * 2, popup.nativePanel.TransformedTop);
}
```

  `redBox(left, top, w, h)` adds a red Box and pumps 3 frames.
  - `UIPanel.TransformedTop` is the panel's top in window pixels: `Top` times the panel's scale.
  - It is added to `UIPanel` and its extern in this task, beside `SetScale`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "Toolkit.scale: roots scaled as heaps does, screen size and pointer in HaxeUI units"
  ```

### Task 25: App exit, icon and window options (G22)

**Files:**
- Modify: `haxe/ui/backend/ToolkitOptions.hx`. Add `@:optional var resizable:Bool; @:optional var minWidth:Int; @:optional var minHeight:Int; @:optional var maximized:Bool;`.
- Modify: `native/Host.cs`.
  - `ConfigureWindow(bool resizable, int minWidth, int minHeight, bool maximized)` is stored like the title, and applied in `CreateWindow`.
  - `SetIcon(byte[] png)` sets a `WindowIcon`.
  - `HasIcon`, `IsResizable`, `MinWidth`, `MinHeight` and `IsMaximized` read the state back.
- Modify: `haxe/ui/backend/AppImpl.hx`.
  - `init` passes the new options to `ConfigureWindow`.
  - `exit()` override: `Host.CloseWindow()`. The normal close path then runs `onEnd` and exits.
  - `set_icon` override loads bytes from a Haxe resource or a file, then calls `Host.SetIcon`.
- Modify: `Native.hx`.
- Create: `tests/cases/TestApp.hx`, registered in `TestMain`.
- Create: `tests/window-app/Main.hx` and `tests/window-app/build.hxml` (desktop, like exit-app).
- Modify: `README.md`. Document the new options, `exit()` and `icon`.

- [ ] **Step 1: Write the failing tests.**

  Headless:
  ```haxe
  function testIcon() {
  	@:privateAccess (cast haxe.ui.HaxeUIApp.instance : AppImpl).icon = "red4x4.png";
  	Assert.isTrue(Host.HasIcon);
  }
  ```
  Use whatever reference to the app `HaxeUIApp` exposes; if it has none, `TestMain` stores its `app` in a static.

  `tests/window-app/Main.hx`:
  1. Options: `{width: 640, height: 480, title: "window-app", resizable: false, minWidth: 300, minHeight: 200, maximized: false}`.
  2. In `ready`, check `!Host.IsResizable && Host.MinWidth == 300 && Host.MinHeight == 200 && !Host.IsMaximized`. Otherwise print and `Host.Exit(2)`.
  3. After 300 ms, call `app.exit()`. Never call `Host.Exit` directly.
  4. `onEnd` prints `window-app: ok`.
- [ ] **Step 2: Run them.**
  Run: `haxe tests/headless.hxml -D test=TestApp`, then `haxe tests/window-app/build.hxml`
  Expected: the first FAILs. The second does not compile (the options don't exist yet), or hangs until killed because `exit()` does nothing. Run it with a 30 s timeout.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both, plus exit-app and the whole suite.** Expected: PASS. window-app prints `window-app: ok` and exits 0.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests README.md
  git commit -m "App: exit(), icon, and resizable/min-size/maximized window options"
  ```

### Task 26: Middle click, horizontal wheel, key press, Cmd as Ctrl (G23)

**Files:**
- Modify: `native/UIEvents.cs`.
  - Add `EventKind.MIDDLE_CLICK = 32768` and `EventKind.KEY_PRESS = 65536`.
  - Middle clicks are made from press and release, as left clicks are.
  - Horizontal wheel: when `Delta.Y == 0 && Delta.X != 0`, deliver WHEEL with `delta = Delta.X` and `shift = true`, because core scrolls sideways on shift+wheel.
  - KEY_PRESS fires from `TextInput` events with `keyCode` = the first character's code.
  - Add `KeyCodes.IsCtrl(int modifiers, bool isMac): bool`, where `modifiers` is Avalonia's `KeyModifiers` flags as an int. Meta counts as Ctrl on macOS. The routers call it with `OperatingSystem.IsMacOS()`.
- Modify: `haxe/ui/backend/cs/EventMapper.hx`. Map MIDDLE_CLICK and KEY_PRESS.
- Modify: `native/TestDriver.cs`. `Wheel` gains `deltaX`; Haxe `TestDriver.wheel(x, y, deltaY, deltaX = 0)`.
- Modify: `Native.hx`. Add the `KeyCodes`/`IsCtrl` extern for the test.
- Test: `tests/cases/TestMouse.hx`, `tests/cases/TestKeys.hx`.

- [ ] **Step 1: Write the failing tests.**

```haxe
// TestMouse
function testMiddleClick() {
	var b = box();
	var n = 0;
	b.registerEvent(MouseEvent.MIDDLE_CLICK, _ -> n++);
	var p = TestDriver.centerOf(b);
	TestDriver.mouseDown(p.x, p.y, 1);
	TestDriver.mouseUp(p.x, p.y, 1);
	TestDriver.pump();
	Assert.equals(1, n);
}

function testHorizontalWheelScrollsSideways() {
	var sv = wideScrollView(); // a 150x90 ScrollView holding a 600x60 Box
	TestDriver.wheel(sv.screenLeft + 50, sv.screenTop + 40, 0, -1);
	TestDriver.pump(3);
	Assert.isTrue(sv.hscrollPos > 0);
}

// TestKeys
function testKeyPress() {
	var f = new TextField();
	Screen.instance.addComponent(f);
	TestDriver.pump(2);
	f.focus = true;
	TestDriver.pump();
	var codes = [];
	f.registerEvent(KeyboardEvent.KEY_PRESS, e -> codes.push(e.keyCode));
	TestDriver.type("a");
	TestDriver.pump();
	Assert.same([97], codes);
}

function testCmdIsCtrlOnMac() {
	Assert.isTrue(KeyCodes.IsCtrl(KeyModifiers_Meta, true));
	Assert.isFalse(KeyCodes.IsCtrl(KeyModifiers_Meta, false));
}
```

  `KeyModifiers_Meta` is the Avalonia `KeyModifiers.Meta` value as an Int (8). The extern takes an Int.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "Input: middle click, horizontal wheel, KEY_PRESS, Cmd as Ctrl on macOS"
  ```

### Task 27: Canvas setPixel (G24)

**Files:**
- Modify: `native/UIGraphics.cs`. Add `SetPixel(int x, int y, uint argb)`, writing into the pixel layer and creating it at the canvas size when absent.
- Modify: `haxe/ui/backend/ComponentGraphicsImpl.hx`, `setPixel`. Convert `Color` to opaque ARGB.
- Modify: `haxe/ui/backend/cs/native/Native.hx`, adding `UIGraphics.SetPixel(x:Int, y:Int, argb:UInt):Void`.
- Test: `tests/cases/TestGraphics.hx`.

- [ ] **Step 1: Write the failing test.** A 20×20 `Canvas` at (0, 0). After `canvas.componentGraphics.setPixel(5, 5, 0xFF0000)` and pump(3), `TestDriver.pixel(5, 5) == 0xFFFF0000` and `TestDriver.pixel(6, 5) != 0xFFFF0000`.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests/cases/TestGraphics.hx
  git commit -m "Canvas setPixel"
  ```

### Task 28: Idle wake-ups and brush reuse (G24)

**Files:**
- Modify: `haxe/ui/backend/AppImpl.hx` and `native/Host.cs`. The desktop Haxe-events pump becomes adaptive:
  - after each `events.progress()`, its result (`Now` / `At(t)` / `AnyTime` / `Never`) sets the next tick;
  - while `Never`, it ticks every 250 ms, so events posted from other threads (Task 5) still arrive.
- Modify: `native/UIStyle.cs`. Cache the background and border brushes, rebuilt only when a colour, opacity or gradient field changes. `StyleMapper` calls a new `UIStyle.Changed()` after filling the fields.
- Modify: `tests/window-app/Main.hx` (Task 25). Before calling `app.exit()`, idle for 2 s and measure `System.Diagnostics.Process.GetCurrentProcess().TotalProcessorTime` across it.

- [ ] **Step 1: Write the failing check.** window-app fails, printing the figure, if the idle CPU time over 2 s is more than 150 ms.
- [ ] **Step 2: Run it.**
  Run: `haxe tests/window-app/build.hxml`
  Expected: FAIL, unless it is already under budget. In that case record the measured figure in the ledger and keep the check as a guard.
- [ ] **Step 3: Implement** the adaptive pump and the brush cache.
- [ ] **Step 4: Run window-app, exit-app and the whole suite.** Expected: PASS. A repeating `haxe.Timer` in exit-app still ticks: its printed tick count is ≥ 5.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "An idle app stays idle; style brushes are reused"
  ```

### Task 29: Resource names, dialog exceptions, dox placement (G24)

**Files:**
- Modify: `haxe/ui/backend/cs/macros/Build.hx`, `resourceItems`. XML-escape `Include` and `LogicalName` (`&`, `<`, `>`, `"`, `'`).
- Modify: `native/FileDialogs.cs`. The bodies of `OpenFiles`, `SaveFile` and `OpenFolder` go in `try/catch`. An exception is written to stderr as `haxeui-cs: a file dialog failed: <e>` and answered as Cancel. A listener that throws is reported the same way; it never escapes an `async void`.
- Modify (core-joe): `haxe/ui/core/Component.hx`. Move the `#if cs releaseFocusWithin` helper so that the `@:dox` comment sits on `removeAllComponents` again (commit e6e1f35b).
- Modify: `tests/headless.hxml`. Add `--resource tests/assets/red4x4.png@odd name & co.png`.
- Test: `tests/cases/TestImages.hx`, `tests/cases/TestDialogs.hx`.

- [ ] **Step 1: Write the failing tests.**
  - `testOddResourceName`: `ToolkitAssets.instance.getImage("odd name & co.png", ...)` gives width 4.
  - `testDialogListenerThrowsIsReported`: with `TestResponse` set, an `IFileDialogListener` whose `OnFiles` throws. The call returns normally, and the next test still runs.
- [ ] **Step 2: Run them.** Expected: the suite build fails, because MSBuild rejects the unescaped `&`; that counts as failing. After escaping, the dialog test FAILs with the exception escaping.
- [ ] **Step 3: Implement** all three changes.
- [ ] **Step 4: Run the whole suite and the heaps gate.** Expected: PASS.
- [ ] **Step 5: Commit both repos.**
  ```bash
  git -C <haxeui-core-joe> commit -am "Component: keep removeAllComponents' doc comment on it"
  git add haxe native tests && git commit -m "Escape resource names in the csproj; file dialog failures are reported, never thrown"
  ```

### Task 30: Phase 3 check

- [ ] **Step 1:** Run the gallery. Every style sample matches html5, except where html5 itself differs by design: the default font size, and 9-slice repeat, which html5 lacks. Fix differences, or ledger them as rulings.
- [ ] **Step 2:** Run the Joeditor gate. Expected: `accept: OK`.
- [ ] **Step 3:** Run `haxe tests/headless.hxml` and the exit-app, early-add and window-app checks. Expected: all exit 0.

---

## Phase 4: html5-only extras

### Task 31: HTML text (G25)

**Files:**
- Modify: `native/UIText.cs`. Add `SetHtml(string html)`, which builds `Inlines` from a small tag scanner:
  - `b`/`strong`, `i`/`em`, `u`, `s`/`strike`, `br`;
  - `font color size face`;
  - `span style="color: #rrggbb"`.
  - Unknown tags are dropped, keeping their text. Entities `&amp; &lt; &gt; &quot; &#NN;` are decoded.
  - `MeasureText` works on inlines too.
- Modify: `haxe/ui/backend/TextDisplayImpl.hx`. `get_supportsHtml` returns true, and `validateData` calls `SetHtml` when `_htmlText` is set.
- Modify: `Native.hx`.
- Test: `tests/cases/TestText.hx`.

- [ ] **Step 1: Write the failing tests.** Use `label.htmlText = ...` and `Pixels`.
  - `testHtmlFontColour`: `<font color="#FF0000">RED</font>` at 24 px shows pixels with R > 200 and G, B < 60.
  - `testHtmlBold`: `<b>WWWW</b>` is wider than `WWWW`.
  - `testHtmlLineBreak`: `one<br>two` is at least 1.8× the height of `one`.
  - `testHtmlUnknownTagKeepsText`: `<blink>x</blink>` is the same width as `x`.
  - `testHtmlEntities`: `a &amp; b` is the same width as text `a & b`.
- [ ] **Step 2: Run them.** Expected: FAIL. The text is stripped plain: no colour, no bold, no line break.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests/cases/TestText.hx
  git commit -m "HTML text on labels: b, i, u, s, br, font and span colours"
  ```

### Task 32: rotation and clip-path directives (G26)

**Files:**
- Create: `haxe/ui/backend/cs/directives/Rotate.hx` and `ClipPath.hx`. Mirror html5's `css/directives/Rotate.hx` and `ClipPath.hx`, with the same value syntax.
- Modify: `haxe/ui/backend/module.xml`. Register `rotation` and `clip-path`.
- Modify: `native/UIPanel.cs`.
  - `SetRotation(double degrees)` rotates about the panel's centre, as CSS's default transform origin does.
  - `SetClipInset(double top, double right, double bottom, double left)`, intersected with any HaxeUI clip; NaN clears it.
- Modify: `Native.hx`.
- Create: `tests/cases/TestDirectives.hx`, registered in `TestMain`.

- [ ] **Step 1: Write the failing tests.**
  - `testRotation`: a red 100×20 Box at (100, 100) with `rotation: 90;` has red at (150, 140) and white at (190, 110).
  - `testClipPathInset`: a red 100×60 Box at (0, 0) with `clip-path: inset(10px 10px 10px 10px);` (html5's syntax) is white at (5, 5) and red at (50, 30).
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add native haxe tests
  git commit -m "rotation and clip-path directives, as html5 has them"
  ```

### Task 33: SVG images (G27)

**Files:**
- Modify: `haxe/ui/backend/cs/macros/Build.hx`. Add one package, the builder's choice.
  - Svg.Skia is the expected one: rasterise `SKSvg`'s picture into a bitmap at the drawn size.
  - Check its compatibility with Avalonia 12.1.4's SkiaSharp version first, and ledger the choice and the reason in the commit.
- Modify: `native/UIImage.cs`. `FromBytes` detects SVG: the bytes start, after whitespace, with `<svg` or `<?xml`. Add `UIImage.IsVector`.
- Create: `tests/assets/square.svg`, a 10×10 viewBox with a full red rectangle, as resource `square.svg`.
- Test: `tests/cases/TestImages.hx`.

- [ ] **Step 1: Write the failing tests.**
  - `testSvgImage`: an `Image` of `square.svg` at 40×40 is red at (20, 20).
  - `testSvgBackground`: a Box with `background-image: "square.svg"` is red at its centre.
- [ ] **Step 2: Run them.** Expected: FAIL. `FromBytes` returns null.
- [ ] **Step 3: Implement.** A vector image renders sharp at its drawn size, not as a scaled-up bitmap.
- [ ] **Step 4: Run them, then the whole suite.** Expected: PASS.
- [ ] **Step 5: Commit.**
  ```bash
  git add haxe native tests
  git commit -m "SVG images in Image and background-image"
  ```

### Task 34: backdrop-filter blur (G28, best effort)

**Files:**
- Modify: `native/UIPanel.cs`, `native/UIStyle.cs`, `haxe/ui/backend/cs/StyleMapper.hx` (`style.backdropFilter`), `Native.hx`.
- Test: `tests/cases/TestFilters.hx`.

- [ ] **Step 1: Write the failing test.**
  - `testBackdropBlur`: a black 10×100 Box at x 100 on the white screen.
  - Over it, a 100×100 Box at (60, 0) with `background-color: #FFFFFF; background-opacity: 0.2; backdrop-filter: blur(4);`.
  - The pixel at (97, 50), just left of the black stripe and under the overlay, is grey (bright between 100 and 700).
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement**, if Avalonia 12 can render what lies behind a panel and blur it: for example a `VisualBrush` of the root, clipped and blurred. Limit the time to the size the spec gives (L).
  - If it cannot be done properly, stop. Remove the test, add a "Limits" line to the README naming `backdrop-filter` and the reason, and ledger `Ruling: backdrop-filter dropped — <reason> — <cost>`.
- [ ] **Step 4: Run it, then the whole suite.** Expected: PASS, or the ruling taken and the suite green.
- [ ] **Step 5: Commit.**
  ```bash
  git add -A native haxe tests README.md
  git commit -m "backdrop-filter: blur"
  ```
  If it was dropped instead, the commit subject is `README: backdrop-filter is a limit`.

### Task 35: Phase 4 check

- [ ] **Step 1:** Run the gallery. Add samples for HTML text, rotation, clip-path, SVG and (if done) backdrop blur. They match html5.
- [ ] **Step 2:** Run the Joeditor gate. Expected: `accept: OK`.
- [ ] **Step 3:** Run the whole suite and the three desktop/early checks. Expected: all exit 0.

---

## Platforms

### Task 36: Linux under WSL (G29)

**Files:**
- Modify: `README.md`. A "Linux" paragraph on what was verified and how to run it.
- Modify: whatever breaks on Linux. Fixes are TDD as usual: the failing test is the Linux run itself.

- [ ] **Step 1: Install .NET 10 in WSL, user-local.** Joe approved this download.
  ```
  wsl -e bash -lc "curl -sSL https://dot.net/v1/dotnet-install.sh -o ~/dotnet-install.sh && bash ~/dotnet-install.sh --channel 10.0 --install-dir ~/.dotnet"
  ```
  Expected: `~/.dotnet/dotnet --list-runtimes` lists `Microsoft.NETCore.App 10.x`.
- [ ] **Step 2: Build on Windows, run under WSL.**
  1. `haxe tests/headless.hxml` builds the suite (and runs it on Windows).
  2. Run the same DLL under WSL: `wsl -e bash -lc "cd <haxeui-cs, as a WSL path> && ~/.dotnet/dotnet tests/bin/bin/Debug/net10.0/TestMain.dll"`

  Expected: `ALL TESTS OK`.
  - Text-metric failures caused by a missing default font are fixed by shipping or choosing a font, not by loosening tests.
  - If WSL lacks fonts entirely, copy `tests/assets/DejaVuSansMono.ttf` and a DejaVu Sans into `~/.fonts` and record that in the README.
- [ ] **Step 3: Desktop under WSLg.** `haxe tests/exit-app/build.hxml` and `haxe tests/window-app/build.hxml` build each app (and run it on Windows). Then run each DLL under WSL with `~/.dotnet/dotnet`. Expected: both exit 0 by themselves.
- [ ] **Step 4: Commit any fixes and the README.**
  ```bash
  git add -A native haxe tests README.md
  git commit -m "Linux: suite and desktop checks pass under WSL"
  ```

### Task 37: Mac (G30): waits for Joe

**Files:**
- Modify: `README.md`. A "Mac" paragraph.
- Modify: whatever breaks on macOS.

- [ ] **Step 1:** Ask Joe for the Mac when everything else is done. This task blocks nothing.
- [ ] **Step 2:** On the Mac, run the headless suite, exit-app and window-app with .NET 10, as Task 36 does. Expected: `ALL TESTS OK`, and both exit 0.
- [ ] **Step 3:** Cmd-as-Ctrl by hand. Add a desktop check, `tests/keys-app/` (it prints each KEY_DOWN's `keyCode` and `ctrlKey`). Pressing Cmd+S prints `83 ctrl=true`.
- [ ] **Step 4: Commit fixes and the README.**
  ```bash
  git add -A native haxe tests README.md
  git commit -m "macOS: suite, desktop checks and Cmd as Ctrl verified"
  ```

### Task 38: README limits and the final run

- [ ] **Step 1:** Rewrite `README.md` "Limits (v1)" as "Limits". List only what is still missing:
  - Mac, if Task 37 has not run;
  - backdrop-filter, if dropped;
  - letter-spacing and line-height (core has none);
  - and every other ruling that left something out.
- [ ] **Step 2:** Run the whole suite, every desktop and early check, the gallery, the Joeditor gate and the heaps gate. Expected: all pass, and the gallery matches html5 everywhere except the README's limits.
- [ ] **Step 3:** Remove the gate worktree: `git -C <JoeClash> worktree remove <JoeClash-gate>`.
- [ ] **Step 4: Commit.**
  ```bash
  git add README.md
  git commit -m "README: what is still missing"
  ```
