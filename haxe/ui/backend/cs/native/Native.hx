package haxe.ui.backend.cs.native;

/**
 * The names the rest of haxeui-cs uses for its .NET-facing classes, which live in `impl`: a module
 * here beside these typedefs would clash with them.
 */

typedef ICallback = haxe.ui.backend.cs.native.impl.Host.ICallback;

typedef IEventsPump = haxe.ui.backend.cs.native.impl.Host.IEventsPump;

typedef IHostListener = haxe.ui.backend.cs.native.impl.Host.IHostListener;

typedef ICloseListener = haxe.ui.backend.cs.native.impl.Host.ICloseListener;

typedef IBackListener = haxe.ui.backend.cs.native.impl.Host.IBackListener;

typedef IPauseListener = haxe.ui.backend.cs.native.impl.Host.IPauseListener;

typedef Host = haxe.ui.backend.cs.native.impl.Host.Host;

typedef HostApplication = haxe.ui.backend.cs.native.impl.Host.HostApplication;

typedef UIClipboard = haxe.ui.backend.cs.native.impl.UIClipboard;

typedef IPanelListener = haxe.ui.backend.cs.native.impl.UIEvents.IPanelListener;

typedef NativeEvents = haxe.ui.backend.cs.native.impl.UIEvents.NativeEvents;

typedef KeyCodes = haxe.ui.backend.cs.native.impl.UIEvents.KeyCodes;

typedef IFileDialogListener = haxe.ui.backend.cs.native.impl.FileDialogs.IFileDialogListener;

typedef FileDialogs = haxe.ui.backend.cs.native.impl.FileDialogs;

typedef PickedFiles = haxe.ui.backend.cs.native.impl.PickedFiles;

typedef Control = haxe.ui.backend.cs.net.Controls.Control;

typedef UIPanel = haxe.ui.backend.cs.native.impl.UIPanel;

typedef UIGraphics = haxe.ui.backend.cs.native.impl.UIGraphics;

typedef UILayers = haxe.ui.backend.cs.native.impl.UILayers;

typedef UIText = haxe.ui.backend.cs.native.impl.UIText;

typedef UIFonts = haxe.ui.backend.cs.native.impl.UIFonts;

typedef ColorMatrix = haxe.ui.backend.cs.native.impl.ColorMatrix;

typedef Inflate = haxe.ui.backend.cs.native.impl.Inflate;

typedef Deflate = haxe.ui.backend.cs.native.impl.Deflate;

typedef UIImage = haxe.ui.backend.cs.native.impl.UIImage;

typedef UIImageView = haxe.ui.backend.cs.native.impl.UIImage.UIImageView;

typedef ITextInputListener = haxe.ui.backend.cs.native.impl.UITextInput.ITextInputListener;

typedef UITextInput = haxe.ui.backend.cs.native.impl.UITextInput;

typedef UIStyle = haxe.ui.backend.cs.native.impl.UIStyle;

#if haxeui_cs_headless
typedef HeadlessDriver = haxe.ui.backend.cs.native.impl.TestDriver.HeadlessDriver;
#end
