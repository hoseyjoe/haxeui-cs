package haxe.ui.backend;

import haxe.ui.backend.cs.native.Native;

class ImageDisplayImpl extends ImageBase {
    /** The Avalonia control drawing this image; it lives in the parent component's panel. **/
    public var imageNative:UIImageView;

    public function new() {
        super();
        imageNative = new UIImageView();
    }

    public override function dispose() {
        if (parentComponent != null) {
            parentComponent.nativePanel.RemoveChild(imageNative);
        }
        super.dispose();
    }

    private override function validateData() {
        imageNative.SetImage(_imageInfo != null ? _imageInfo.data : null);
    }

    private override function validatePosition() {
        imageNative.SetBounds(_left, _top, Math.NaN, Math.NaN);
    }

    private override function validateDisplay() {
        imageNative.SetBounds(Math.NaN, Math.NaN, _imageWidth, _imageHeight);
        if (_imageClipRect != null) {
            // the clip rect is in the component's coordinates; the view draws from (_left, _top)
            imageNative.SetClip(true, _imageClipRect.left - _left, _imageClipRect.top - _top, _imageClipRect.width, _imageClipRect.height);
        } else {
            imageNative.SetClip(false, 0, 0, 0, 0);
        }
    }
}
