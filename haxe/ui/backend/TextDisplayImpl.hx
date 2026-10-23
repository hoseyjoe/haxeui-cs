package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native;

class TextDisplayImpl extends TextBase {
    /** The Avalonia TextBlock showing this text; it lives in the parent component's panel. **/
    public var textNative:UIText;

    public function new() {
        super();
        textNative = new UIText();
    }

    private override function validateData() {
        var text = _text != null ? _text : (_htmlText != null ? stripHtml(_htmlText) : "");
        if (textNative.Text != text) {
            textNative.Text = text;
        }
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
            var key = '$family|$size|$bold|$italic|$underline';
            if (key != _fontKey) {
                _fontKey = key;
                applyFont(family, size, bold, italic, underline);
                measureTextRequired = true;
            }
            var color = _textStyle.color != null ? _textStyle.color : 0x000000;
            applyColor(cast(0xFF000000 | (color & 0xFFFFFF)));
            applyAlign(switch (_textStyle.textAlign) {
                case "center": 1;
                case "right": 2;
                case _: 0;
            });
        }
        return measureTextRequired;
    }

    private function applyWrap(wrap:Bool) {
        textNative.SetWrap(wrap);
    }

    private function applyFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool) {
        textNative.SetFont(family, size, bold, italic, underline);
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
