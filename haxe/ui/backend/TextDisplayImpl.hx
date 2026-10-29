package haxe.ui.backend;

import haxe.ui.backend.cs.TextLinkEvent;
import haxe.ui.backend.cs.directives.LineHeight;
import haxe.ui.backend.cs.directives.TextShadow;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Component;
import haxe.ui.events.MouseEvent;

class TextDisplayImpl extends TextBase {
    /** The Avalonia TextBlock showing this text; it lives in the parent component's panel. **/
    public var textNative:UIText;

    public function new() {
        super();
        textNative = new UIText();
    }

    private override function get_supportsHtml():Bool {
        return true;
    }

    private override function validateData() {
        if (_text == null && _htmlText != null && supportsHtml) {
            textNative.SetHtml(_htmlText);
            listenForLinkClicks();
            return;
        }
        var text = _text != null ? _text : (_htmlText != null ? stripHtml(_htmlText) : "");
        textNative.SetHtml(null);
        listenForLinkClicks();
        if (textNative.Text != text) {
            textNative.Text = text;
        }
    }

    // ---- links (`<a href>` in htmlText) and line boxes, in the parent component's units ----

    /** haxeui-cs: how many links the htmlText holds. **/
    public function linkCount():Int {
        return textNative.LinkCount;
    }

    /** haxeui-cs: a link's href, by its place in the text (0 is the first), or null. **/
    public function linkHref(index:Int):Null<String> {
        return textNative.LinkHref(index);
    }

    /** haxeui-cs: the link at a point in the parent component's own units, or -1. **/
    public function linkAt(x:Float, y:Float):Int {
        return textNative.LinkAt(x - _left, y - _top);
    }

    /**
     * haxeui-cs: every link's areas in the parent component's own units, one for each line a
     * link is on.
     */
    public function linkRects():Array<{index:Int, left:Float, top:Float, width:Float, height:Float}> {
        var r = textNative.LinkRects();
        return [for (i in 0...Std.int(r.Length / 5)) {
            index: Std.int(r[i * 5]),
            left: _left + r[i * 5 + 1],
            top: _top + r[i * 5 + 2],
            width: r[i * 5 + 3],
            height: r[i * 5 + 4]
        }];
    }

    /**
     * haxeui-cs: the top and height of each line the text is laid out in, in the parent
     * component's own units: where a page could be cut between lines.
     */
    public function lineBoxes():Array<{top:Float, height:Float}> {
        var b = textNative.LineBoxes();
        return [for (i in 0...Std.int(b.Length / 2)) {top: _top + b[i * 2], height: b[i * 2 + 1]}];
    }

    private var _linkClicks:Component = null;
    /** A click on a link dispatches a TextLinkEvent on the component, while the text has links. **/
    private function listenForLinkClicks() {
        var want = textNative.LinkCount > 0 ? parentComponent : null;
        if (want == _linkClicks) {
            return;
        }
        if (_linkClicks != null) {
            _linkClicks.unregisterEvent(MouseEvent.CLICK, onLinkClick);
        }
        _linkClicks = want;
        if (_linkClicks != null) {
            _linkClicks.registerEvent(MouseEvent.CLICK, onLinkClick);
        }
    }

    private function onLinkClick(e:MouseEvent) {
        var component = _linkClicks;
        if (component == null) {
            return;
        }
        var index = linkAt(e.screenX - component.screenLeft, e.screenY - component.screenTop);
        if (index < 0) {
            return;
        }
        var event = new TextLinkEvent(TextLinkEvent.LINK);
        event.href = textNative.LinkHref(index);
        event.index = index;
        component.dispatch(event);
    }

    private var _fontKey:String = null;
    private var _wordWrap:Null<Bool> = null;
    private override function validateStyle():Bool {
        var measureTextRequired = false;
        if (_wordWrap != _displayData.wordWrap) {
            _wordWrap = _displayData.wordWrap;
            applyWrap(_displayData.wordWrap);
            measureTextRequired = true;
        }

        if (_textStyle != null) {
            var family:String = _fontInfo != null ? _fontInfo.data : null;
            var size:Float = _textStyle.fontSize != null ? _textStyle.fontSize : 0;
            var bold = _textStyle.fontBold == true;
            var italic = _textStyle.fontItalic == true;
            var underline = _textStyle.fontUnderline == true;
            var strikethrough = _textStyle.fontStrikeThrough == true;
            var key = '$family|$size|$bold|$italic|$underline|$strikethrough';
            if (key != _fontKey) {
                _fontKey = key;
                applyFont(family, size, bold, italic, underline, strikethrough);
                measureTextRequired = true;
            }
            var color = _textStyle.color != null ? _textStyle.color : 0x000000;
            applyColor(cast(0xFF000000 | (color & 0xFFFFFF)));
            applyAlign(switch (_textStyle.textAlign) {
                case "center": 1;
                case "right": 2;
                case "justify": 3;
                case _: 0;
            });
        }
        applyShadowDirective();
        if (applyLineHeightDirective()) {
            measureTextRequired = true;
        }
        return measureTextRequired;
    }

    private var _lineHeight:Float = 0;
    /** The haxeui-cs line-height directive; true when it changed the text's height. **/
    private function applyLineHeightDirective():Bool {
        var directive = (_textStyle != null && _textStyle.customDirectives != null) ? _textStyle.customDirectives.get("line-height") : null;
        var height = directive != null ? LineHeight.parse(directive.value, textNative.FontSize) : 0;
        if (height == _lineHeight) {
            return false;
        }
        _lineHeight = height;
        textNative.SetLineHeight(height);
        return true;
    }

    private var _shadowKey:String = null;
    /** The haxeui-cs text-shadow directive, read from the style each time it is validated. **/
    private function applyShadowDirective() {
        var directive = (_textStyle != null && _textStyle.customDirectives != null) ? _textStyle.customDirectives.get("text-shadow") : null;
        var shadow = directive != null ? TextShadow.parse(directive.value) : null;
        var key = shadow == null ? "" : '${shadow.dx}|${shadow.dy}|${shadow.blur}|${shadow.argb}';
        if (key == _shadowKey) {
            return;
        }
        _shadowKey = key;
        if (shadow == null) {
            applyShadow(0, 0, 0, 0);
        } else {
            applyShadow(shadow.dx, shadow.dy, shadow.blur, shadow.argb);
        }
    }

    private function applyShadow(dx:Float, dy:Float, blur:Float, argb:UInt) {
        textNative.SetShadow(dx, dy, blur, argb);
    }

    private function applyWrap(wrap:Bool) {
        textNative.SetWrap(wrap);
    }

    private function applyFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool, strikethrough:Bool) {
        textNative.SetFont(family, size, bold, italic, underline, strikethrough);
    }

    private function applyColor(argb:UInt) {
        textNative.SetColor(argb);
    }

    private function applyAlign(align:Int) {
        textNative.SetAlign(align);
    }

    private override function validatePosition() {
        textNative.SetBounds(_left, _top, Math.NaN, Math.NaN);
    }

    private override function validateDisplay() {
        textNative.SetBounds(Math.NaN, Math.NaN, _width, _height);
    }

    private override function measureText() {
        textNative.MeasureText(_displayData.wordWrap && _width > 0 ? _width : 0);
        _textWidth = textNative.MeasuredWidth;
        _textHeight = textNative.MeasuredHeight;
    }

    private static function stripHtml(html:String):String {
        return ~/<[^>]*>/g.replace(html, "");
    }
}
