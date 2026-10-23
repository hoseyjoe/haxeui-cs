package haxe.ui.backend;

import haxe.io.Bytes;
import haxe.ui.assets.FontInfo;
import haxe.ui.assets.ImageInfo;
import haxe.ui.backend.cs.native.Native.UIImage;

class AssetsImpl extends AssetsBase {
    /** Haxe resources are decoded by getImageFromHaxeResource; anything else is tried as a file. **/
    private override function getImageInternal(resourceId:String, callback:ImageInfo->Void) {
        if (resourceId == null || haxe.Resource.listNames().indexOf(resourceId) != -1 || !sys.FileSystem.exists(resourceId)) {
            callback(null);
            return;
        }
        imageFromBytes(sys.io.File.getBytes(resourceId), callback);
    }

    private override function getImageFromHaxeResource(resourceId:String, callback:String->ImageInfo->Void) {
        imageFromBytes(haxe.Resource.getBytes(resourceId), function(imageInfo) {
            callback(resourceId, imageInfo);
        });
    }

    public override function imageFromBytes(bytes:Bytes, callback:ImageInfo->Void) {
        var image = bytes != null ? UIImage.FromBytes(bytes.getData()) : null;
        callback(image != null ? imageInfoFromImageData(image) : null);
    }

    public override function imageInfoFromImageData(imageData:ImageData):ImageInfo {
        return {
            data: imageData,
            width: imageData.Width,
            height: imageData.Height
        };
    }

    /**
     * Fonts are system font families, looked up by name. A name that looks
     * like a font file is not supported yet: answering null leaves the text in
     * the default family.
     */
    private override function getFontInternal(resourceId:String, callback:FontInfo->Void) {
        if (resourceId == null || resourceId.indexOf(".") != -1 || resourceId.indexOf("/") != -1) {
            callback(null);
            return;
        }
        callback({name: resourceId, data: resourceId});
    }
}
