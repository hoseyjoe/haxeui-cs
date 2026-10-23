package haxe.ui.backend;

import haxe.io.Bytes;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.core.Component;
import haxe.ui.util.Color;
import haxe.ui.util.Variant;

/**
 * Canvas drawing on the native panel. Like haxeui-heaps, commands wait in
 * ComponentGraphicsBase until the component first has a size, then replay;
 * fills follow heaps' Flash model (see native/UIGraphics.cs).
 */
class ComponentGraphicsImpl extends ComponentGraphicsBase {
    private var _hasSize:Bool = false;
    private var _graphics:UIGraphics;

    public function new(component:Component) {
        super(component);
        _graphics = new UIGraphics();
        component.nativePanel.SetGraphics(_graphics);
    }

    public override function clear() {
        if (_hasSize == false) {
            return super.clear();
        }
        _graphics.Clear();
    }

    public override function setPixel(x:Float, y:Float, color:Color) {
        if (_hasSize == false) {
            return super.setPixel(x, y, color);
        }
    }

    public override function setPixels(pixels:Bytes) {
        if (_hasSize == false) {
            return super.setPixels(pixels);
        }
        _graphics.SetPixels(pixels.getData(), Std.int(_component.width), Std.int(_component.height));
    }

    public override function moveTo(x:Float, y:Float) {
        if (_hasSize == false) {
            return super.moveTo(x, y);
        }
        _graphics.MoveTo(x, y);
    }

    public override function lineTo(x:Float, y:Float) {
        if (_hasSize == false) {
            return super.lineTo(x, y);
        }
        _graphics.LineTo(x, y);
    }

    public override function strokeStyle(color:Null<Color>, thickness:Null<Float> = 1, alpha:Null<Float> = 1) {
        if (_hasSize == false) {
            return super.strokeStyle(color, thickness, alpha);
        }
        _graphics.StrokeStyle(color != null, argb(color, alpha), thickness != null ? thickness : 1);
    }

    public override function circle(x:Float, y:Float, radius:Float) {
        if (_hasSize == false) {
            return super.circle(x, y, radius);
        }
        _graphics.Circle(x, y, radius);
    }

    public override function fillStyle(color:Null<Color>, alpha:Null<Float> = 1) {
        if (_hasSize == false) {
            return super.fillStyle(color, alpha);
        }
        _graphics.FillStyle(color != null, argb(color, alpha));
    }

    public override function curveTo(controlX:Float, controlY:Float, anchorX:Float, anchorY:Float) {
        if (_hasSize == false) {
            return super.curveTo(controlX, controlY, anchorX, anchorY);
        }
        _graphics.CurveTo(controlX, controlY, anchorX, anchorY);
    }

    public override function cubicCurveTo(controlX1:Float, controlY1:Float, controlX2:Float, controlY2:Float, anchorX:Float, anchorY:Float) {
        if (_hasSize == false) {
            return super.cubicCurveTo(controlX1, controlY1, controlX2, controlY2, anchorX, anchorY);
        }
        _graphics.CubicCurveTo(controlX1, controlY1, controlX2, controlY2, anchorX, anchorY);
    }

    public override function rectangle(x:Float, y:Float, width:Float, height:Float) {
        if (_hasSize == false) {
            return super.rectangle(x, y, width, height);
        }
        _graphics.Rectangle(x, y, width, height);
    }

    public override function image(resource:Variant, x:Null<Float> = null, y:Null<Float> = null, width:Null<Float> = null, height:Null<Float> = null) {
        if (_hasSize == false) {
            return super.image(resource, x, y, width, height);
        }
        if (resource == null) {
            return;
        }
        var draw = function(image:ImageData) {
            if (image == null) {
                return;
            }
            _graphics.Image(image, x != null ? x : 0, y != null ? y : 0, width != null ? width : image.Width, height != null ? height : image.Height);
        }
        if (resource.isImageData) {
            draw(resource.toImageData());
        } else {
            Toolkit.assets.getImage(resource.toString(), info -> draw(info != null ? info.data : null));
        }
    }

    public override function beginPath() {
        if (_hasSize == false) {
            return super.beginPath();
        }
        _graphics.BeginPath();
    }

    public override function closePath() {
        if (_hasSize == false) {
            return super.closePath();
        }
        _graphics.ClosePath();
    }

    public override function resize(width:Null<Float>, height:Null<Float>) {
        if (width > 0 && height > 0 && _hasSize == false) {
            _hasSize = true;
            replayDrawCommands();
        }
    }

    private static function argb(color:Null<Color>, alpha:Null<Float>):UInt {
        if (color == null) {
            return 0;
        }
        var a = Std.int(Math.max(0, Math.min(1, alpha != null ? alpha : 1)) * 255);
        return cast((a << 24) | ((color:Int) & 0xFFFFFF));
    }
}
