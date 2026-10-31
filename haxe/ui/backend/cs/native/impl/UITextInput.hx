package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.EventArgs;
import cs.system.EventHandler;
import cs.system.EventHandler_1;
import cs.system.Exception;
import cs.system.Type;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;

/** What a UITextInput tells the HaxeUI side. */
@:native("HaxeUICs.ITextInputListener")
@:nativeGen
interface ITextInputListener {
	function OnTextChanged():Void;
	function OnScrollChanged():Void;
	function OnFocus(focused:Bool):Void;
}

/**
 * A HaxeUI text input: an Avalonia TextBox with its own chrome stripped (HaxeUI's style paints
 * the field around it) and its scrollbars hidden (HaxeUI draws those too). Pointer and key
 * events keep bubbling to the owning component, as an HTML input's do.
 */
@:native("HaxeUICs.UITextInput")
@:nativeGen
class UITextInput extends TextBox implements IColorFiltered {
	var _matrix:NativeArray<Single>;
	var _color:UInt = 0xFF000000;
	var _selectionColor:UInt = 0;
	var _shadowX = 0.0;
	var _shadowY = 0.0;
	var _shadowBlur = 0.0;
	var _shadowColor:UInt = 0;

	public function SetEffectiveColorMatrix(matrix:NativeArray<Single>):Void {
		_matrix = matrix;
		SetColor(_color);
		if (_selectionColor != 0) {
			SetSelectionColor(_selectionColor);
		}
		SetShadow(_shadowX, _shadowY, _shadowBlur, _shadowColor);
	}

	var _listener:ITextInputListener;
	var _scroll:ScrollViewer;
	var _settingText = false;

	// Use TextBox's control theme: a subclass would otherwise get no template at all.
	@:protected @:property override function get_StyleKeyOverride():Type {
		return cs.Lib.toNativeType(TextBox);
	}

	public function new() {
		super();
		Background = Brushes.Transparent;
		BorderThickness = new Thickness(0);
		Padding = new Thickness(0);
		MinWidth = 0;
		MinHeight = 0;
		IsTabStop = false; // HaxeUI's FocusManager owns tab order
		NewLine = "\n";
		VerticalContentAlignment = VerticalAlignment.Top;
		ScrollViewer.SetHorizontalScrollBarVisibility(this, ScrollBarVisibility.Hidden);
		ScrollViewer.SetVerticalScrollBarVisibility(this, ScrollBarVisibility.Hidden);

		var changed:EventHandler_1<AvaloniaPropertyChangedEventArgs> = function(s:Dynamic, e:AvaloniaPropertyChangedEventArgs) {
			if (e.Property == TextBox.TextProperty && !_settingText && _listener != null) {
				_listener.OnTextChanged();
			}
		};
		add_PropertyChanged(changed);
		var gotFocus:EventHandler_1<FocusChangedEventArgs> = function(s:Dynamic, e:FocusChangedEventArgs) {
			if (_listener != null) {
				_listener.OnFocus(true);
			}
		};
		add_GotFocus(gotFocus);
		var lostFocus:EventHandler_1<FocusChangedEventArgs> = function(s:Dynamic, e:FocusChangedEventArgs) {
			if (_listener != null) {
				_listener.OnFocus(false);
			}
		};
		add_LostFocus(lostFocus);
	}

	public function SetListener(listener:ITextInputListener):Void {
		_listener = listener;
	}

	/** Sets the text from code: no OnTextChanged, so HaxeUI never hears its own write. */
	public function SetText(text:String):Void {
		var value = text == null ? "" : text;
		if (Text == value) {
			return;
		}
		_settingText = true;
		try {
			Text = value;
		} catch (e:Exception) {
			_settingText = false;
			throw e;
		}
		_settingText = false;
	}

	public var IsPassword(get, never):Bool;

	function get_IsPassword():Bool {
		return (cast PasswordChar : Int) != 0;
	}

	public function SetMultiline(multiline:Bool):Void {
		AcceptsReturn = multiline;
	}

	public function SetWordWrap(wrap:Bool):Void {
		TextWrapping = wrap ? Wrap : NoWrap;
		// A hidden scrollbar still lets the text be as wide as it likes, so it never wraps;
		// a disabled one holds it to the box's width.
		ScrollViewer.SetHorizontalScrollBarVisibility(this, wrap ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Hidden);
	}

	public function SetPassword(password:Bool):Void {
		PasswordChar = password ? 0x2022 : 0;
	}

	public function SetSelectionColor(argb:UInt):Void {
		_selectionColor = argb;
		SelectionBrush = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)), 1.0);
	}

	public function SetFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool, strikethrough:Bool):Void {
		FontFamily = UIFonts.ResolveFamily(family);
		FontSize = size > 0 ? size : 13;
		FontWeight = bold ? Bold : Normal;
		FontStyle = italic ? Italic : Normal;
		if (underline != _underline || strikethrough != _strikethrough) {
			_underline = underline;
			_strikethrough = strikethrough;
			InvalidateVisual();
		}
	}

	// A TextBox (and its TextPresenter) has no TextDecorations in Avalonia 12, so the lines
	// are drawn here, under the presenter, from its text layout: one per laid-out line.
	var _underline = false;
	var _strikethrough = false;
	var _presenter:TextPresenter;

	override public function Render(context:DrawingContext):Void {
		super.Render(context);
		var layout = _presenter == null ? null : _presenter.TextLayout;
		if ((!_underline && !_strikethrough) || layout == null) {
			return;
		}
		var translated = VisualExtensions.TranslatePoint(_presenter, new Point(0, 0), this);
		var origin = translated.HasValue ? translated.Value : new Point(0, 0);
		var pen = new Pen(Foreground, Math.max(1, cs.system.Math.Round(FontSize / 14)), null, PenLineCap.Flat, PenLineJoin.Miter, 10);
		var clip = context.PushClip(new Rect(0, 0, Bounds.Width, Bounds.Height));
		try {
			var top = origin.Y;
			var lines = layout.TextLines;
			var all:IReadOnlyCollection<TextLine> = lines;
			for (i in 0...all.Count) {
				var line:TextLine = lines[i];
				var left = origin.X + line.Start;
				if (line.Width > 0) {
					if (_underline) {
						var y = top + line.Baseline + pen.Thickness + 1;
						context.DrawLine(pen, new Point(left, y), new Point(left + line.Width, y));
					}
					if (_strikethrough) {
						var y = top + line.Baseline - FontSize * 0.3;
						context.DrawLine(pen, new Point(left, y), new Point(left + line.Width, y));
					}
				}
				top += line.Height;
			}
		} catch (e:Exception) {
			clip.Dispose();
			throw e;
		}
		clip.Dispose();
	}

	public function SetColor(argb:UInt):Void {
		_color = argb;
		var brush = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)), 1.0);
		Foreground = brush;
		CaretBrush = brush;
	}

	/** 0 left, 1 center, 2 right, 3 justify. */
	public function SetAlign(align:Int):Void {
		TextAlignment = align == 1 ? Center : align == 2 ? Right : align == 3 ? Justify : Left;
	}

	/** A shadow of the glyphs (haxeui-cs's text-shadow); argb 0 removes it. */
	public function SetShadow(dx:Float, dy:Float, blur:Float, argb:UInt):Void {
		_shadowX = dx;
		_shadowY = dy;
		_shadowBlur = blur;
		_shadowColor = argb;
		var mapped:UInt = argb == 0 ? 0 : ColorMatrix.Apply(_matrix, argb);
		if (mapped == 0) {
			Effect = null;
			return;
		}
		var shadow = new DropShadowEffect();
		shadow.OffsetX = dx;
		shadow.OffsetY = dy;
		shadow.BlurRadius = Math.max(0, blur);
		var opaque:UInt = 0xFF000000;
		shadow.Color = Color.FromUInt32(mapped | opaque);
		shadow.Opacity = ((mapped >> 24) & 0xFF) / 255.0;
		Effect = shadow;
	}

	/** Sets position and size; NaN leaves that value as it was. */
	public function SetBounds(left:Float, top:Float, width:Float, height:Float):Void {
		if (!Math.isNaN(left)) {
			Canvas.SetLeft(this, left);
		}
		if (!Math.isNaN(top)) {
			Canvas.SetTop(this, top);
		}
		if (!Math.isNaN(width)) {
			Width = Math.max(0, width);
		}
		if (!Math.isNaN(height)) {
			Height = Math.max(0, height);
		}
	}

	public var ScrollX(get, never):Float;
	public var ScrollY(get, never):Float;
	public var ExtentWidth(get, never):Float;
	public var ExtentHeight(get, never):Float;
	public var ViewportWidth(get, never):Float;
	public var ViewportHeight(get, never):Float;

	function get_ScrollX():Float {
		return _scroll == null ? 0 : _scroll.Offset.X;
	}

	function get_ScrollY():Float {
		return _scroll == null ? 0 : _scroll.Offset.Y;
	}

	function get_ExtentWidth():Float {
		return _scroll == null ? 0 : _scroll.Extent.Width;
	}

	function get_ExtentHeight():Float {
		return _scroll == null ? 0 : _scroll.Extent.Height;
	}

	function get_ViewportWidth():Float {
		return _scroll == null ? 0 : _scroll.Viewport.Width;
	}

	function get_ViewportHeight():Float {
		return _scroll == null ? 0 : _scroll.Viewport.Height;
	}

	public function SetScroll(x:Float, y:Float):Void {
		if (_scroll != null && (_scroll.Offset.X != x || _scroll.Offset.Y != y)) {
			_scroll.Offset = new Vector(x, y);
		}
	}

	public function Blur():Void {
		if (!IsFocused) {
			return;
		}
		var top = TopLevel.GetTopLevel(this);
		if (top != null && top.FocusManager != null) {
			top.FocusManager.Focus(null, NavigationMethod.Unspecified, KeyModifiers.None);
		}
	}

	@:protected override function OnApplyTemplate(e:TemplateAppliedEventArgs):Void {
		super.OnApplyTemplate(e);
		_scroll = cast e.NameScope.Find("PART_ScrollViewer");
		_presenter = cast e.NameScope.Find("PART_TextPresenter");
		if (_presenter != null) {
			var updated:EventHandler = function(s:Dynamic, a:EventArgs) {
				if (_underline || _strikethrough) {
					InvalidateVisual();
				}
			};
			_presenter.add_LayoutUpdated(updated);
		}
		if (_scroll != null) {
			var scrolled:EventHandler_1<ScrollChangedEventArgs> = function(s:Dynamic, a:ScrollChangedEventArgs) {
				if (_underline || _strikethrough) {
					InvalidateVisual(); // the lines follow the text
				}
				if (_listener != null) {
					_listener.OnScrollChanged();
				}
			};
			_scroll.add_ScrollChanged(scrolled);
		}
	}

	@:protected override function OnPointerPressed(e:PointerPressedEventArgs):Void {
		super.OnPointerPressed(e);
		e.Handled = false; // the owning component still hears the press (it is what focuses it in HaxeUI)
	}

	@:protected override function OnPointerReleased(e:PointerReleasedEventArgs):Void {
		super.OnPointerReleased(e);
		e.Handled = false;
	}
}
