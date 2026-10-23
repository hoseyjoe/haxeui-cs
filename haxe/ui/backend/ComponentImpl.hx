package haxe.ui.backend;

import haxe.ui.backend.cs.StyleMapper;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Component;
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
        nativePanel.ApplyStyle(_nativeStyle);
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

    private static inline function orNaN(value:Null<Float>):Float {
        return value != null ? value : Math.NaN;
    }
}
