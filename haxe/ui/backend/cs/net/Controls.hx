package haxe.ui.backend.cs.net;

import cs.StdTypes.Char16;
import cs.system.EventArgs;
import cs.system.EventHandler;
import cs.system.EventHandler_1;
import cs.system.Type;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Input;
import haxe.ui.backend.cs.net.Media;

/** Externs for Avalonia's control tree, written by hand as hxc binds them, along the real class chain. */
@:native("Avalonia.AvaloniaProperty")
extern class AvaloniaProperty {}

@:native("Avalonia.AvaloniaPropertyChangedEventArgs")
extern class AvaloniaPropertyChangedEventArgs extends EventArgs {
	var Property(default, never):AvaloniaProperty;
}

@:native("Avalonia.AvaloniaObject")
extern class AvaloniaObject {
	@:event private var PropertyChanged:EventHandler_1<AvaloniaPropertyChangedEventArgs>;
	function add_PropertyChanged(value:EventHandler_1<AvaloniaPropertyChangedEventArgs>):Void;
	function remove_PropertyChanged(value:EventHandler_1<AvaloniaPropertyChangedEventArgs>):Void;
}

@:native("Avalonia.Visual")
extern class Visual extends AvaloniaObject {
	@:protected private var StyleKeyOverride(get, never):Type;
	private function get_StyleKeyOverride():Type;
	var Bounds(default, never):Rect;
	var IsVisible:Bool;
	var Effect:IEffect;
	var Clip:Geometry;
	function InvalidateVisual():Void;
	function Render(context:DrawingContext):Void;
}

@:native("Avalonia.VisualExtensions")
extern class VisualExtensions {
	static function TranslatePoint(visual:Visual, point:Point, relativeTo:Visual):cs.system.Nullable_1<Point>;
	static function TransformToVisual(from:Visual, to:Visual):cs.system.Nullable_1<Matrix>;
}

@:native("Avalonia.VisualTree.VisualExtensions")
extern class VisualTreeExtensions {
	static function GetVisualDescendants(visual:Visual):cs.system.collections.generic.IEnumerable_1<Visual>;
}

@:native("Avalonia.Layout.VerticalAlignment")
extern enum VerticalAlignment {
	Stretch;
	Top;
	Center;
	Bottom;
}

@:native("Avalonia.Layout.Layoutable")
extern class Layoutable extends Visual {
	var Width:Float;
	var Height:Float;
	var MinWidth:Float;
	var MinHeight:Float;
	@:event private var LayoutUpdated:EventHandler;
	function add_LayoutUpdated(value:EventHandler):Void;
	function remove_LayoutUpdated(value:EventHandler):Void;
}

@:native("Avalonia.Input.InputElement")
extern class InputElement extends Layoutable implements IInputElement {
	var IsEnabled:Bool;
	var IsFocused(default, never):Bool;
	var IsHitTestVisible:Bool;
	var IsTabStop:Bool;
	function Focus():Bool;
	@:event private var GotFocus:EventHandler_1<FocusChangedEventArgs>;
	function add_GotFocus(value:EventHandler_1<FocusChangedEventArgs>):Void;
	function remove_GotFocus(value:EventHandler_1<FocusChangedEventArgs>):Void;
	@:event private var LostFocus:EventHandler_1<FocusChangedEventArgs>;
	function add_LostFocus(value:EventHandler_1<FocusChangedEventArgs>):Void;
	function remove_LostFocus(value:EventHandler_1<FocusChangedEventArgs>):Void;
	@:protected private function OnPointerPressed(e:PointerPressedEventArgs):Void;
	@:protected private function OnPointerReleased(e:PointerReleasedEventArgs):Void;
}

/** Avalonia's base control. **/
@:native("Avalonia.Controls.Control")
extern class Control extends InputElement {
	function new();
}

@:native("Avalonia.Media.RenderOptions")
@:struct
extern class RenderOptions {
	static function SetBitmapInterpolationMode(visual:Visual, value:BitmapInterpolationMode):Void;
}

@:native("Avalonia.Controls.INameScope")
extern interface INameScope {
	function Find(name:String):cs.system.Object;
}

@:native("Avalonia.Controls.Primitives.TemplateAppliedEventArgs")
extern class TemplateAppliedEventArgs extends RoutedEventArgs {
	var NameScope(default, never):INameScope;
}

@:native("Avalonia.Controls.Primitives.TemplatedControl")
extern class TemplatedControl extends Control {
	var Background:IBrush;
	var BorderThickness:Thickness;
	var Padding:Thickness;
	var FontFamily:FontFamily;
	var FontSize:Float;
	var FontStyle:FontStyle;
	var FontWeight:FontWeight;
	var Foreground:IBrush;
	@:protected private function OnApplyTemplate(e:TemplateAppliedEventArgs):Void;
}

@:native("Avalonia.Controls.TextBox")
extern class TextBox extends TemplatedControl {
	function new();
	static var TextProperty(default, never):AvaloniaProperty;
	var Text:String;
	var AcceptsReturn:Bool;
	var CaretIndex:Int;
	var CaretBrush:IBrush;
	var NewLine:String;
	var PasswordChar:Char16;
	var SelectionBrush:IBrush;
	var SelectionStart:Int;
	var SelectionEnd:Int;
	var TextAlignment:TextAlignment;
	var TextWrapping:TextWrapping;
	var VerticalContentAlignment:VerticalAlignment;
}

@:native("Avalonia.Controls.Primitives.ScrollBarVisibility")
extern enum ScrollBarVisibility {
	Disabled;
	Auto;
	Hidden;
	Visible;
}

@:native("Avalonia.Controls.ScrollChangedEventArgs")
extern class ScrollChangedEventArgs extends RoutedEventArgs {}

@:native("Avalonia.Controls.ScrollViewer")
extern class ScrollViewer extends TemplatedControl {
	var Offset:Vector;
	var Extent(default, never):Size;
	var Viewport(default, never):Size;
	static function SetHorizontalScrollBarVisibility(control:Control, value:ScrollBarVisibility):Void;
	static function SetVerticalScrollBarVisibility(control:Control, value:ScrollBarVisibility):Void;
	@:event private var ScrollChanged:EventHandler_1<ScrollChangedEventArgs>;
	function add_ScrollChanged(value:EventHandler_1<ScrollChangedEventArgs>):Void;
	function remove_ScrollChanged(value:EventHandler_1<ScrollChangedEventArgs>):Void;
}

@:native("Avalonia.Controls.Canvas")
extern class Canvas {
	static function SetLeft(element:AvaloniaObject, value:Float):Void;
	static function SetTop(element:AvaloniaObject, value:Float):Void;
}

@:native("Avalonia.Controls.TopLevel")
extern class TopLevel extends TemplatedControl {
	static function GetTopLevel(visual:Visual):TopLevel;
	var FocusManager(default, never):IFocusManager;
	var RenderScaling(default, never):Float;
}

@:native("Avalonia.Controls.Presenters.TextPresenter")
extern class TextPresenter extends Control {
	var TextLayout(default, never):TextLayout;
}
