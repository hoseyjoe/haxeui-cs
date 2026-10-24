package haxe.ui.backend.cs.loaders;

import haxe.io.Bytes;
import haxe.ui.assets.ImageInfo;
import haxe.ui.loaders.image.ImageLoaderBase;
import haxe.ui.util.Variant;

/** An image given as SVG markup itself ("<svg ...>...</svg>", or "svg://..."), as html5 allows. **/
class SvgImageLoader extends ImageLoaderBase {
	public override function load(resource:Variant, callback:ImageInfo->Void) {
		var svg:String = resource.toString();
		if (StringTools.startsWith(svg, "svg://")) {
			svg = svg.substr("svg://".length);
		}
		Toolkit.assets.imageFromBytes(Bytes.ofString(svg), callback);
	}
}
