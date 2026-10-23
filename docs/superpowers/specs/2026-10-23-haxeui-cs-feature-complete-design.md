# haxeui-cs feature completeness: design

Date: 2026-10-23. Status: draft, awaiting Joe's approval.

Calls marked **[builder's call]** are Claude's, not Joe's. Everything else was
decided with Joe in conversation, or comes straight from the inventory below.

## Intent

v1 (`docs/superpowers/specs/2026-10-22-haxeui-cs-design.md`) made haxeui-cs good
enough to run Joeditor. Joe now wants it **feature complete for HaxeUI**: a
HaxeUI app should work on haxeui-cs as it does on the other backends, with
nothing quietly missing. In Joe's words: "Those that you mentioned and the ones
you mentioned before so I could rebuild joeditor but anything else as well."

This is **project 1 of 2**:

- **Project 1 (this document):** the backend, plus the haxeui-core-joe fixes it
  needs.
- **Project 2 (a later design):** Joeditor with no placeholders. It needs the
  GameFont, the map-label shadow, the figure preview and Joenimating's Animate
  column. Project 2 builds on what project 1 delivers, and is designed
  separately.

**Order (Joe's decision):**
1. Fix the bugs.
2. Build what Joeditor needs from the backend.
3. Do the rest of parity.

## Where things stand: the inventory (2026-10-23)

The inventory had three parts:

- **A probe app** (`spike/probe/`, gitignored). It was built for haxeui-cs (headless) and for haxeui-html5 as the reference, and photographed in light and dark themes. It covered:
  - all 103 component classes core declares;
  - 20 data-filled samples;
  - 19 style samples.
- **A read of every style property** core parses, compared across html5, heaps and cs.
- **A read of every backend hook, event and platform feature**, compared the same way.

**What works:** all 87 creatable components lay out, draw and click like html5.
That includes popups, tooltips, `@keyframes` animation, clip, gradients, radius,
opacity, background-image repeat and stretch, image scale modes,
bold/italic/underline, and the dark theme. The other 16 classes:

- 6 are not components;
- 9 fail to compile on C# (bug 8);
- 1 needs a parent TreeView.

The gaps below are everything the inventory found missing. Sizes: **S** is
about an hour or two, **M** about half a day to a day, **L** more than that.

## Goals

### Phase 1: bugs

1. **TextArea never wraps** (S). This hits Joeditor's prose fields, which set
   `wrap = true`.
   - Cause: `native/UITextInput.cs:42` sets the horizontal scrollbar to `Hidden`. That still gives the text unlimited width.
   - Fix: wrapping needs `Disabled`; not wrapping keeps `Hidden`.
2. **A newly made TextArea shows as focused** (S). It has a caret and the focus
   border before anyone clicks it; html5 shows neither. Find the cause and fix
   it, so native focus stops drifting away from HaxeUI's.
   - Do **not** add a bridge that turns native TextBox focus changes into HaxeUI focus changes. html5 has none: FOCUS_IN and FOCUS_OUT come only from HaxeUI's FocusManager.
   - Joeditor commits its field edits on FOCUS_OUT (`PropertyPanel.hx`). Extra FOCUS_OUTs, from removals, window deactivation or dialogs, would change when it commits.
   - **[builder's call]**, following html5.
3. **Key codes** (S). `KeyCodes.FromKey` (`native/UIEvents.cs`) falls back to
   Avalonia's own enum values for unmapped keys. The fix is the full
   browser-style table for every key Avalonia reports. Today's wrong cases:
   - CapsLock reads as 8 (Backspace) and the Windows key as 70 ('F');
   - numpad `* + - . /` read as letters;
   - OEM punctuation, NumLock, Pause, PrintScreen, ContextMenu and F13–F24 are wrong.

   Right values include 20 for CapsLock, 106–111 for the numpad operators, 186–222 for punctuation, 144 for NumLock and 124–135 for F13–F24.
4. **HTTP images** (S, core-joe). The `#elseif cs` branch of
   `haxe/ui/loaders/image/HttpImageLoader.hx` has two faults:
   - it blocks the UI thread on `WebRequest.GetResponse()`;
   - a 404 or being offline throws an uncaught exception.

   The fix: load asynchronously with `HttpClient`, report a failed load as no image (as the other loaders do), and hand the result back on the UI thread.
5. **Adding a component before the window exists** crashes with a
   NullReferenceException (S). `Host.Root` is null until `CreateWindow`.
   `HaxeUIApp` adds its preloader before init whenever a module declares
   preloads. Such components must appear once the window does.
6. **OpenFolderDialog** shows core's error stub (S). Add `OpenFolderDialogImpl`
   on Avalonia's `StorageProvider.OpenFolderPickerAsync`, shaped like the
   existing open and save dialogs.
7. **One exception during layout freezes the UI for good** (S, core-joe).
   - Cause: `ValidationManager.process()` sets `isValidating = true` with no `try/finally`. After one throw, every later validation is skipped. On cs the frame queue reports the throw and carries on, so the app looks alive but never lays out again.
   - Fix: after a throw, the manager is left so that the next invalidation schedules a fresh pass, and the exception still propagates. This is correct on every target, so it carries no `#if cs`. Concretely:
     - `isValidating` and `isPending` are restored in a `finally`. Restoring only `isValidating` is not enough: `isPending` stays true, so `add()` never schedules `process()` again.
     - The component that threw has its own `_isValidating` reset, which needs a `finally` in `ComponentBase.validateComponent`.
     - The items after it stay queued for the next frame. The one that threw has already left the queue, so it comes back only if something invalidates it again; a fault does not repeat 60 times a second on its own.
     - Joe's SpinGuard clears the queue before it throws. A cycle would only spin again next frame, so its trace and throw happen once, as now.
     - **[builder's call]**: this policy.
   - The test drives a throw through the real frame loop (`callLater` and the frame timer). It must not call `process()` directly as `TestDriver.pump` does, or it would pass on the broken code.
8. **Three core modules don't compile for C#** (S–M, core-joe):
   - `containers/Collapsible.hx`: method calls on untyped `findComponent` results, which C# sees as `object`.
   - `containers/properties/PropertyGroup.hx`: the same fault.
   - `containers/SideBar.hx`: `super.hide()` inside a constructor. Haxe's C# output puts constructor bodies in a static method, where `base` is illegal.

   The fixes should be correct on every target where they can be: typed locals for the first two. The SideBar fix may need an `#if cs` branch. Done means every module of `haxe.ui.components` and `haxe.ui.containers` compiles for C# with `-dce no`.

### Phase 2: what Joeditor needs from the backend

9. **Font files** (M). Today a `font-name` that names a `.ttf` or `.otf` is ignored.
   - It should render in that font, wherever the name points:
     - a Haxe resource (as `getFontFromHaxeResource` on html5);
     - a file path relative to the working directory;
     - an absolute file path.
   - `FontData` may stop being a bare family name.
   - Avalonia 12 can load a face from a stream: `FontCollectionBase.TryAddGlyphTypeface(Stream, out GlyphTypeface)` on a collection registered with `FontManager.Current.AddFontCollection`.
   - Bold and italic still apply, synthesised where the file has no such face.
   - Project 2 uses this for `res/GameFont.ttf`.
10. **Shadows** (M). The default theme uses `filter` shadows in about 30 places:
    - `$normal-inner-shadow` on 15 pressed and checked controls;
    - shadows on dialogs, menus, popups, windows and cards.

    Today none draw. Shadows follow **html5 exactly, in their numbers and in what they shadow**, because the theme's numbers were tuned for html5 (`haxe/ui/backend/html5/FilterHelper.hx`). All of them shadow the component's background box (Avalonia `BoxShadow` on the rounded rectangle; `IsInset` for inset):
    - **`drop-shadow(distance, angle, colour, alpha, blurX, blurY, …, inner=false)`**: offset (distance, distance + 2), blur `blurX - 1`, spread `blurY - 1`. Angle, strength and quality are ignored, as html5 ignores them.
    - **`drop-shadow(…, inner=true)`**: inset, offset (distance, distance), blur `blurX`, spread 0.
    - **`box-shadow(offsetX, offsetY, colour, alpha, blurRadius, spreadRadius, inset)`**: as written.

    Heaps reads the same numbers differently (a fixed 45°, doubled alpha, blur 1), and literal Flash would make the theme's shadows nearly opaque. **[builder's call]**: html5, the reference.
11. **Text shadow** (S–M). This is a haxeui-cs CSS directive,
    `text-shadow: <x>px <y>px <blur>px <colour> [<alpha>]`. It shadows the
    glyphs of a component's text (labels and text inputs).
    - Register it in haxeui-cs `module.xml` as a custom directive, as html5 registers `rotation`, so core keeps it.
    - Why it exists: core has no text-shadow, and html5's drop-shadow shadows the box, not the glyphs. Joeditor's map labels need a crisp 1-pixel black edge behind white text (heaps: `dx 1, dy 1, black, alpha 0.9`, no blur). Project 2 writes `text-shadow: 1px 1px 0px #000000 0.9` in MapView's cs branch, in place of the heaps sprite reach-through.
    - Other backends ignore an unknown directive.
    - **[builder's call]**: the syntax.
12. **Blur** (S). `filter: blur(n)` blurs the component and its contents, as
    CSS `filter: blur` does (Avalonia `BlurEffect`). The theme blurs
    `.modal-component` this way.

The canvas calls the figure preview needs (lineStyle, moveTo, lineTo,
beginFill, endFill) already work from v1. Project 2 adds the adapter in
JoeClash.

### Phase 3: the rest of parity

13. **Per-side borders with a radius** (M). These draw as square rectangles
    today (`UIPanel.cs`). They should follow the radius, as heaps and html5 do:
    sides of different widths or colours meet at rounded corners.
14. **`border-style: dashed | dotted`** (S–M), on uniform and per-side
    borders. `solid` and `none` keep today's behaviour.
15. **Text decoration** (S). Two parts:
    - `text-decoration: line-through` (`fontStrikeThrough`) on labels and inputs;
    - `font-underline` on text inputs, where `SetFont` ignores it today.
16. **`text-align: justify`** (S). It falls back to left today.
17. **Backgrounds** (S each):
    - `background-width/-height` (background-size, px and %);
    - 9-slice with repeated edges and centre (heaps);
    - the background image clipped to the border radius (html5);
    - `image-rendering: pixelated` on images and background images.
18. **Cursors** (S). Every CSS cursor name Avalonia's `StandardCursorType` can
    stand in for, including:
    - `none`, `not-allowed`, `wait`, `crosshair`, `help`, `grab`/`grabbing`;
    - the edge and corner resize names Window uses (`nwse-`, `nesw-`, `ns-`, `ew-resize`).

    Two core behaviours that are html5-only today also reach cs: disabled components drop their cursor (`ComponentBase.hx:566-605`), and splitter and window drags hold the cursor on the whole screen.
19. **Generic font families** (S). `monospace`, `serif`, `sans-serif`,
    `cursive` and `system-ui` map to sensible installed families on each OS.
    `monospace` falls back to the default font today.
20. **Colour filters** (L). The default theme uses `grayscale` on disabled images and colour pickers. The full set is grayscale, tint, brightness, contrast, saturate, hue-rotate and invert.
    - Semantics follow html5: the CSS filter functions (brightness multiplies) and tint's SVG colour matrix, applied to the component and its contents as CSS `filter` is.
    - Avalonia 12 has no colour-matrix effect for a subtree.
    - **[builder's call]**, suggested: transform colours and bitmaps at paint time. Each painter, text and image under a filtered component maps its own colours and pixels through the matrix; filtered bitmaps are cached.
21. **`Toolkit.scale`** (M). It is ignored today. It should scale the whole UI as html5 does:
    - the screen size seen by HaxeUI is the window size divided by the scale;
    - pointer coordinates are in HaxeUI units;
    - text and images stay sharp (a layout scale, not a bitmap stretch).
22. **App and window** (S):
    - `app.exit()` closes the window and ends the process as closing it does;
    - `app.icon` sets the window icon;
    - `ToolkitOptions` gains `resizable`, `minWidth`, `minHeight` and `maximized`;
    - `ready()` keeps its v1 blocking behaviour on the desktop.
23. **Input** (S):
    - `MIDDLE_CLICK`;
    - horizontal wheel (`Delta.X`);
    - `KEY_PRESS`, as heaps maps it.
    - On macOS, Cmd is reported as `ctrlKey`, so the Ctrl shortcuts that HaxeUI apps register work there. Core's `KeyboardEvent` has no `metaKey`. **[builder's call]**
24. **v1's deferred minors**:
    - `setPixel`/`setPixels` on the canvas (a no-op today);
    - idle CPU: the 10 ms Haxe-events timer and the frame timer must not wake an idle app 100 times a second for nothing;
    - brushes rebuilt on every render;
    - raw resource names in the generated csproj (escape them);
    - `async void` file dialogs (exceptions must reach the caller's error path, not crash);
    - the `@:dox` placement in core commit e6e1f35b.

### Phase 4: html5-only extras (Joe: in, but last)

25. **HTML text** (M). Support `htmlText` and `content-type: html` on labels.
    - Supported subset: `b`, `i`, `u`, `s`, `br`, `font color/size/face`, `span style="color"`.
    - Other tags are stripped as now.
    - `supportsHtml` returns true.
26. **html5's custom directives** (S each): `rotation` (degrees) and
    `clip-path: inset(...)`, registered in `module.xml` so core keeps them.
27. **SVG images** (M), in `Image` and `background-image`. This may add one
    package (Svg.Skia or similar). **[builder's call]** which.
28. **`backdrop-filter: blur`** (L). Best effort.
    - If Avalonia 12 cannot blur what lies behind a component without disproportionate work, the builder may drop it.
    - Dropping it must be recorded in the README's limits, with the reason.

### Platforms

29. **Linux** (M). Run the headless suite and the desktop exit check under
    WSL Ubuntu (WSLg for the window). Fix what breaks.
    - WSL today has only the .NET 8 SDK from apt: no .NET 10 and no Haxe.
    - **Joe's decision:** Claude installs .NET 10 into the WSL home folder with Microsoft's `dotnet-install` script. That needs no sudo, and the download is approved.
    - Builds stay on Windows. WSL runs the built DLLs, so Haxe is not installed there.
    - The suite's Linux run means the Windows-built headless DLL running under WSL's .NET 10.
30. **Mac** (M). Build and run the headless suite and the desktop exit check on Joe's Mac. Fix what breaks, including verifying goal 23's Cmd-as-Ctrl.
    - Joe has a Mac and will make it available when he is ready. This task waits for him and does not block anything else; it is the last task.
    - Until it has run, the README says Mac "should work, untested".

## Non-goals

These are things no backend has, or that do not apply to a composite backend
on .NET:

- `native` styling and native or hybrid scrollers (html5-only, browser controls);
- `letter-spacing` and `line-height`: core does not parse them. (`text-shadow` is goal 11, as a haxeui-cs directive.)
- `background-position-x/y` and `cursor-offset-x/y`: core parses them, but no backend reads them;
- the `outline` filter: no backend implements it;
- OS file drag-and-drop into the window: core has no API for it;
- a clipboard API: core has none, and text inputs already copy and paste natively;
- numeric `font-weight` beyond bold.
- **Project 2's work:**
  - the figure-graphics adapter and FigurePane;
  - the MapView shadow switch;
  - EditorFont using the `.ttf`;
  - Joenimating.

  Project 1 only makes these possible.

## Anti-goals (a failure even if it technically works)

- **A core change that alters behaviour on html5 or heaps.** Core-joe changes are `#if cs` or correct on every target, as the commit policy says. JoeClash's heaps builds and its rules suite (353/353) keep passing.
- **Joeditor's C# build getting worse.** `haxe tools.joeditor.cs.hxml` with `-D haxeui_cs_headless --cs-accept` passes after every phase.
- **Effects that make ordinary apps slow.** Shadows and filters cost only on the components that use them, and an idle app stays idle.
- **Heavy dependencies.** Anything beyond Avalonia and SkiaSharp (which Avalonia already brings) needs a reason in the commit.
- **Faking parity.** A feature that cannot be done properly is listed in the README's limits, never shipped half-working and silent.

## Constraints

- **Tools:** Haxe 4.3.7, .NET 10, Avalonia 12.1.4. haxeui-core-joe is the `haxelib dev` checkout every build uses.
- **Commit policy** (Joe's standing rules):
  - commit in haxeui-cs freely;
  - core fixes go straight to haxeui-core-joe master;
  - JoeClash changes go only through a worktree branch, never Joe's checkout (he has uncommitted work there);
  - nothing is ever pushed.

  Project 1 should not need JoeClash changes. If one is needed, it waits for project 2.
- **Tests first:** every goal gets a headless test (utest, `haxe tests/headless.hxml`) that fails before the change. Drawing goals assert rendered pixels with `TestDriver.pixel` / `capture`, as v1's style tests do. Colours in tests are 6-digit hex: core reads `#f00` as `0x000F00`.
- **Behaviour reference:** html5 is the reference, in shadows and filters too. The one heaps item is 9-slice with repeated edges, which html5 does not have.

## Verification

- **The suite:** `haxe tests/headless.hxml` stays green after every goal (154 assertions today, growing).
- **Parity gallery:** the probe is promoted to a committed tool, `tools/gallery/` **[builder's call]**. It builds the same pages for haxeui-cs (headless, PNGs) and html5. A script photographs the html5 build with headless Edge and writes side-by-side comparisons.
  - Run it at the end of each phase, and look at the result.
  - Every visible difference is either fixed or listed in the README's limits.
- **Joeditor:** `--cs-accept` passes after each phase. After phase 2, a one-off check builds Joeditor with the GameFont named in a style and a `text-shadow` on a map label. This check is not committed to JoeClash.
- **Desktop checks:** `tests/exit-app` still exits by itself. `app.exit()` and the window options get a desktop check of the same kind.
- **README:** "Limits" is rewritten to what is actually still missing.

## Left to the builder

- **Ordering inside a phase.** Phase order is fixed.
- **Native-layer structure:** new classes, how effects attach to `UIPanel`, how fonts are cached.
- **Exact cursor mappings** where CSS and Avalonia differ.
- **Choices marked [builder's call] above.** Each is reported back if it turns out wrong.
- **When to ask instead:** a gap that turns out much bigger than its size (an S that is really an L) is raised with Joe before it is built, not after.
