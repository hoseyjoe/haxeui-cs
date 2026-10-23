package haxe.ui.backend;

import haxe.ui.assets.FontInfo;

class AssetsImpl extends AssetsBase {
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
