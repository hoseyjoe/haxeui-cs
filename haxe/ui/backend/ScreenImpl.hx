package haxe.ui.backend;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.EventMapper;
import haxe.ui.backend.cs.InputListener;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Component;
import haxe.ui.events.UIEvent;

/** The window's root panel: root components' panels are its children, in z-order. **/
class ScreenImpl extends ScreenBase {
    private var _mapping:Map<String, UIEvent->Void> = new Map<String, UIEvent->Void>();
    private var _input:InputListener = new InputListener();
    private var _appliedScaleX:Float = 1;
    private var _appliedScaleY:Float = 1;

    public function new() {
        // ScreenBase declares `rootComponents = []` but has no constructor to run it from.
        rootComponents = [];
    }

    // Sizes are in HaxeUI's units: the window's size over Toolkit.scale.
    private override function get_width():Float {
        return Host.ClientWidth / Toolkit.scaleX;
    }

    private override function get_height():Float {
        return Host.ClientHeight / Toolkit.scaleY;
    }

    private override function get_title():String {
        return Host.Title;
    }

    private override function set_title(value:String):String {
        Host.Title = value;
        return value;
    }

    public override function addComponent(component:Component):Component {
        // Toolkit.scale is taken up as root components arrive (as heaps does). Those already up were
        // placed under the old one: their screen pixels mean something else under the new transform.
        Host.SetScale(Toolkit.scaleX, Toolkit.scaleY);
        if (Toolkit.scaleX != _appliedScaleX || Toolkit.scaleY != _appliedScaleY) {
            _appliedScaleX = Toolkit.scaleX;
            _appliedScaleY = Toolkit.scaleY;
            for (root in rootComponents) {
                @:privateAccess root.placeNative();
            }
        }
        Host.Root.InsertChild(component.nativePanel, Host.Root.ChildCount);
        @:privateAccess component.placeNative(); // a root's position is screen pixels (ComponentImpl.handlePosition)
        resizeComponent(component);
        return component;
    }

    public override function removeComponent(component:Component, dispose:Bool = true, invalidate:Bool = true):Component {
        Host.Root.RemoveChild(component.nativePanel);
        return component;
    }

    private override function handleSetComponentIndex(child:Component, index:Int) {
        Host.Root.MoveChild(child.nativePanel, index);
    }

    private override function supportsEvent(type:String):Bool {
        return type == UIEvent.RESIZE || EventMapper.kindOf(type) != 0;
    }

    private override function mapEvent(type:String, listener:UIEvent->Void) {
        if (type == UIEvent.RESIZE) {
            _mapping.set(type, listener);
            return;
        }
        _input.mapping.set(type, listener);
        Host.ListenScreen(_input.mask, _input);
    }

    private override function unmapEvent(type:String, listener:UIEvent->Void) {
        if (type == UIEvent.RESIZE) {
            _mapping.remove(type);
            return;
        }
        _input.mapping.remove(type);
        Host.ListenScreen(_input.mask, _input);
    }

    /** The window's client area changed size. **/
    @:allow(haxe.ui.backend.AppImpl)
    private function onHostResize() {
        resizeRootComponents();
        var listener = _mapping.get(UIEvent.RESIZE);
        if (listener != null) {
            listener(new UIEvent(UIEvent.RESIZE));
        }
    }
}
