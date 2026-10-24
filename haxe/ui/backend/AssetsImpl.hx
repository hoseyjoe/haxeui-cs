package haxe.ui.backend;

import haxe.io.Bytes;
import haxe.ui.assets.FontInfo;
import haxe.ui.assets.ImageInfo;
import haxe.ui.backend.cs.NativeBytes;
import haxe.ui.backend.cs.native.Native.UIFonts;
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
        var image = bytes != null ? UIImage.FromBytes(NativeBytes.of(bytes)) : null;
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
     * A font is a system family named as such ("Segoe UI"), or a font file: a Haxe resource
     * (answered by getFontFromHaxeResource) or a .ttf/.otf/.ttc on disk. Anything else that
     * looks like a file, or a file that is not a font, answers null: the default family.
     */
    private override function getFontInternal(resourceId:String, callback:FontInfo->Void) {
        if (resourceId == null || haxe.Resource.listNames().indexOf(resourceId) != -1) {
            callback(null); // a resource: core asks getFontFromHaxeResource next
            return;
        }
        if (isFontFile(resourceId)) {
            fontInfo(resourceId, UIFonts.FromFile(resourceId), callback);
            return;
        }
        if (resourceId.indexOf(".") != -1 || resourceId.indexOf("/") != -1 || resourceId.indexOf("\\") != -1) {
            callback(null);
            return;
        }
        callback({name: resourceId, data: resourceId});
    }

    private override function getFontFromHaxeResource(resourceId:String, callback:String->FontInfo->Void) {
        var bytes = haxe.Resource.getBytes(resourceId);
        fontInfo(resourceId, bytes != null ? UIFonts.FromBytes(resourceId, NativeBytes.of(bytes)) : null, function(info) {
            callback(resourceId, info);
        });
    }

    private static function fontInfo(name:String, family:String, callback:FontInfo->Void) {
        callback(family != null ? {name: name, data: family} : null);
    }

    private static function isFontFile(name:String):Bool {
        var lower = name.toLowerCase();
        return StringTools.endsWith(lower, ".ttf") || StringTools.endsWith(lower, ".otf") || StringTools.endsWith(lower, ".ttc");
    }
}
