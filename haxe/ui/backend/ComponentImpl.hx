package haxe.ui.backend;

import haxe.ui.backend.cs.ColorFilters;
import haxe.ui.backend.cs.EventMapper;
import haxe.ui.backend.cs.InputListener;
import haxe.ui.backend.cs.StyleMapper;
import haxe.ui.events.UIEvent;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Component;
import haxe.ui.core.ImageDisplay;
import haxe.ui.core.TextDisplay;
import haxe.ui.core.TextInput;
import haxe.ui.util.Variant;
import haxe.ui.geom.Rectangle;
import haxe.ui.styles.Style;

class ComponentImpl extends ComponentBase {
    /** This component's Avalonia surface; each child component's panel is a child of it. **/
    public var nativePanel:UIPanel;

    private override function handleCreate(native:Bool) {
        if (nativePanel == null) {
            nativePanel = new UIPanel();
        }
    }

    private override function handlePosition(left:Null<Float>, top:Null<Float>, style:Style) {
        if (nativePanel == null) {
            return;
        }
        nativePanel.SetBounds(orNaN(left), orNaN(top), Math.NaN, Math.NaN);
    }

    private override function handleSize(width:Null<Float>, height:Null<Float>, style:Style) {
        if (nativePanel == null) {
            return;
        }
        nativePanel.SetBounds(Math.NaN, Math.NaN, orNaN(width), orNaN(height));
    }

    private var _nativeStyle:UIStyle;

    private override function applyStyle(style:Style) {
        if (nativePanel == null) {
            return;
        }
        if (_nativeStyle == null) {
            _nativeStyle = new UIStyle();
        }
        StyleMapper.toNative(style, _nativeStyle);
        applyBackgroundImage(style.backgroundImage);
        nativePanel.ApplyStyle(_nativeStyle);
        nativePanel.SetColorMatrix(ColorFilters.matrixFor(style.filter));
        if (_imageDisplay != null) {
            _imageDisplay.imageNative.SetPixelated(style.imageRendering == "pixelated");
        }
    }

    public override function createTextInput(text:String = null):TextInput {
        if (_textInput == null) {
            super.createTextInput(text);
            nativePanel.AddContent(_textInput.inputNative);
        }
        return _textInput;
    }

    private var _backgroundImageId:String = null;
    private function applyBackgroundImage(image:Variant) {
        if (image == null) {
            _backgroundImageId = null;
            _nativeStyle.BackgroundImage = null;
        } else if (image.isImageData) {
            _backgroundImageId = null;
            _nativeStyle.BackgroundImage = image.toImageData();
        } else {
            var id = image.toString();
            if (id == _backgroundImageId) {
                return;
            }
            _backgroundImageId = id;
            _nativeStyle.BackgroundImage = null;
            Toolkit.assets.getImage(id, function(info) {
                if (_backgroundImageId != id) {
                    return; // the style moved on while this loaded
                }
                _nativeStyle.BackgroundImage = info != null ? info.data : null;
                nativePanel.ApplyStyle(_nativeStyle);
            });
        }
    }

    public override function createImageDisplay():ImageDisplay {
        if (_imageDisplay == null) {
            super.createImageDisplay();
            nativePanel.AddContent(_imageDisplay.imageNative);
            var current = cast(this, haxe.ui.core.Component).style;
            _imageDisplay.imageNative.SetPixelated(current != null && current.imageRendering == "pixelated");
        }
        return _imageDisplay;
    }

    private var _input:InputListener;

    private override function mapEvent(type:String, listener:UIEvent->Void) {
        if (EventMapper.kindOf(type) == 0) {
            return;
        }
        if (_input == null) {
            _input = new InputListener();
        }
        _input.mapping.set(type, listener);
        nativePanel.Listen(_input.mask, _input);
    }

    private override function unmapEvent(type:String, listener:UIEvent->Void) {
        if (_input == null || !_input.mapping.exists(type)) {
            return;
        }
        _input.mapping.remove(type);
        nativePanel.Listen(_input.mask, _input);
    }

    private override function handleFrameworkProperty(id:String, value:Any) {
        switch (id) {
            case "allowMouseInteraction":
                // pointer-events: none — clicks pass through this component and everything in it,
                // as CSS's inherited pointer-events does on html5.
                nativePanel.IsHitTestVisible = (value == true);
        }
    }

    private override function handleDisabled(disable:Bool) {
        // html5 strips a disabled component's cursor in core; here the panel does it
        nativePanel.SetCursorSuppressed(disable);
    }

    private override function handleVisibility(show:Bool) {
        nativePanel.SetVisible(show);
    }

    private override function handleClipRect(value:Rectangle) {
        if (value == null) {
            nativePanel.SetClip(false, 0, 0, 0, 0);
        } else {
            nativePanel.SetClip(true, value.left, value.top, value.width, value.height);
        }
    }

    private override function handleAddComponent(child:Component):Component {
        nativePanel.InsertChild(child.nativePanel, nativePanel.ChildCount);
        return child;
    }

    private override function handleAddComponentAt(child:Component, index:Int):Component {
        nativePanel.InsertChild(child.nativePanel, index);
        return child;
    }

    private override function handleRemoveComponent(child:Component, dispose:Bool = true):Component {
        nativePanel.RemoveChild(child.nativePanel);
        return child;
    }

    private override function handleRemoveComponentAt(index:Int, dispose:Bool = true):Component {
        var child = cast(this, Component).childComponents[index];
        if (child != null) {
            nativePanel.RemoveChild(child.nativePanel);
        }
        return child;
    }

    private override function handleSetComponentIndex(child:Component, index:Int) {
        nativePanel.MoveChild(child.nativePanel, index);
    }

    public override function createTextDisplay(text:String = null):TextDisplay {
        if (_textDisplay == null) {
            super.createTextDisplay(text);
            nativePanel.AddContent(_textDisplay.textNative);
        }
        return _textDisplay;
    }

    private static inline function orNaN(value:Null<Float>):Float {
        return value != null ? value : Math.NaN;
    }
}
