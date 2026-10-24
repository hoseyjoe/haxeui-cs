package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native;

/**
 * An editable text: a native TextBox (`inputNative`) shown in the parent
 * component's panel. The inherited `textNative` is never shown; it measures
 * the same text and font for HaxeUI's layout.
 */
class TextInputImpl extends TextDisplayImpl {
    /** The colour of selected text's highlight, for every text input (Joeditor sets it). **/
    public static var selectionColor:Int = 0x3390FF;

    public var inputNative:UITextInput;

    public function new() {
        super();
        _displayData.multiline = false;
        inputNative = new UITextInput();
        inputNative.SetListener(new TextInputListener(this));
    }

    public override function focus() {
        inputNative.Focus();
    }

    public override function blur() {
        inputNative.Blur();
    }

    private override function get_caretIndex():Int {
        return inputNative.CaretIndex;
    }

    private override function set_caretIndex(value:Int):Int {
        inputNative.CaretIndex = value;
        return value;
    }

    private override function get_selectionStartIndex():Int {
        return inputNative.SelectionStart;
    }

    private override function set_selectionStartIndex(value:Int):Int {
        inputNative.SelectionStart = value;
        return value;
    }

    private override function get_selectionEndIndex():Int {
        return inputNative.SelectionEnd;
    }

    private override function set_selectionEndIndex(value:Int):Int {
        inputNative.SelectionEnd = value;
        return value;
    }

    private override function validateData() {
        super.validateData();
        inputNative.SetText(_text != null ? _text : "");
        inputNative.SetScroll(_inputData.hscrollPos, _inputData.vscrollPos);
    }

    private override function validateStyle():Bool {
        var measureTextRequired = super.validateStyle();
        inputNative.SetMultiline(_displayData.multiline);
        inputNative.SetPassword(_inputData.password);
        inputNative.SetSelectionColor(cast(0xFF000000 | (selectionColor & 0xFFFFFF)));
        if (parentComponent != null) {
            inputNative.IsEnabled = !parentComponent.disabled;
        }
        return measureTextRequired;
    }

    private override function applyWrap(wrap:Bool) {
        super.applyWrap(wrap);
        inputNative.SetWordWrap(wrap);
    }

    private override function applyFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool, strikethrough:Bool) {
        super.applyFont(family, size, bold, italic, underline, strikethrough);
        inputNative.SetFont(family, size, bold, italic, underline, strikethrough);
    }

    private override function applyColor(argb:UInt) {
        super.applyColor(argb);
        inputNative.SetColor(argb);
    }

    private override function applyShadow(dx:Float, dy:Float, blur:Float, argb:UInt) {
        super.applyShadow(dx, dy, blur, argb);
        inputNative.SetShadow(dx, dy, blur, argb);
    }

    private override function applyAlign(align:Int) {
        super.applyAlign(align);
        inputNative.SetAlign(align);
    }

    private override function validatePosition() {
        inputNative.SetBounds(_left, _top, Math.NaN, Math.NaN);
    }

    private override function validateDisplay() {
        inputNative.SetBounds(Math.NaN, Math.NaN, _width, _height);
        updateScrollData();
    }

    /** The user changed the text. **/
    private function onNativeTextChanged() {
        _text = inputNative.Text;
        textNative.Text = _text;
        measureText();
        if (_inputData.onChangedCallback != null) {
            _inputData.onChangedCallback();
        }
    }

    private function onNativeScroll() {
        updateScrollData();
        if (_inputData.onScrollCallback != null) {
            _inputData.onScrollCallback();
        }
    }

    private function updateScrollData() {
        _inputData.hscrollPos = inputNative.ScrollX;
        _inputData.vscrollPos = inputNative.ScrollY;
        _inputData.hscrollMax = Math.max(0, inputNative.ExtentWidth - inputNative.ViewportWidth);
        _inputData.vscrollMax = Math.max(0, inputNative.ExtentHeight - inputNative.ViewportHeight);
        _inputData.hscrollPageSize = inputNative.ExtentWidth > 0 ? (inputNative.ViewportWidth * _inputData.hscrollMax) / inputNative.ExtentWidth : 0;
        _inputData.vscrollPageSize = inputNative.ExtentHeight > 0 ? (inputNative.ViewportHeight * _inputData.vscrollMax) / inputNative.ExtentHeight : 0;
    }
}

@:access(haxe.ui.backend.TextInputImpl)
private class TextInputListener implements ITextInputListener {
    var input:TextInputImpl;

    public function new(input:TextInputImpl) {
        this.input = input;
    }

    public function OnTextChanged():Void {
        input.onNativeTextChanged();
    }

    public function OnScrollChanged():Void {
        input.onNativeScroll();
    }

    public function OnFocus(focused:Bool):Void {
    }
}
