package haxe.ui.backend.cs;

import haxe.io.Bytes;
import haxe.ui.backend.cs.native.Native.UIImage;
import haxe.ui.backend.cs.native.Native.UILayers;
import haxe.ui.core.Component;

/**
 * Retained layers on a component's canvas, drawn above its canvas drawing: groups, each with a
 * matrix, an opacity and an optional mask, holding bitmaps placed in their group's units. For
 * content that moves every frame while its pixels mostly don't, such as an animated SVG's layers:
 * placing a group again costs a repaint, where `setPixels` every frame rasterises it all again on
 * the CPU. A bitmap may have more pixels than units, so it stays sharp at `deviceScale`.
 *
 *     var layers = canvas.componentGraphics.layers;
 *     var g = layers.addGroup();
 *     var b = layers.addBitmap(g);
 *     layers.setPixels(b, rgba, 200, 100, 0, 0, 100, 50);   // 2 pixels per unit
 *     layers.setMatrix(g, 1, 0, 0, 1, 10, 10);              // moved 10 units right and down
 *
 * A haxeui-cs addition: other backends have their own scene to drop to (h2d, the DOM).
 */
class Layers {
	private var _native:UILayers;
	private var _component:Component;

	private function new(native:UILayers, component:Component) {
		_native = native;
		_component = component;
	}

	/** How many layers there are; they are numbered from 0 as they are added. **/
	public var count(get, never):Int;

	private function get_count():Int {
		return _native.Count;
	}

	/**
	 * Device pixels per unit where the component draws: the screen's scale (1.5 on a 150% monitor)
	 * times `Toolkit.scale`. 1 until the component is on screen.
	 */
	public var deviceScale(get, never):Float;

	private function get_deviceScale():Float {
		return UIImage.DeviceScale(_component.nativePanel);
	}

	/** A new group inside `parent` (-1: at the top), drawn above what is already there. **/
	public function addGroup(parent:Int = -1):Int {
		return _native.AddGroup(parent);
	}

	/** A new bitmap inside `parent` (-1: at the top), drawn above what is already there; empty until `setPixels`. **/
	public function addBitmap(parent:Int = -1):Int {
		return _native.AddBitmap(parent);
	}

	/** Places a layer in its group: x' = a·x + c·y + e, y' = b·x + d·y + f, as SVG's matrix(a b c d e f). **/
	public function setMatrix(layer:Int, a:Float, b:Float, c:Float, d:Float, e:Float, f:Float) {
		_native.SetMatrix(layer, a, b, c, d, e, f);
	}

	/** 0 to 1. A group is faded as one image, as SVG and CSS fade one. **/
	public function setOpacity(layer:Int, opacity:Float) {
		_native.SetOpacity(layer, opacity);
	}

	public function setVisible(layer:Int, visible:Bool) {
		_native.SetVisible(layer, visible);
	}

	/**
	 * A bitmap's pixels, or a group's mask (its alpha: nothing of the group shows outside it). RGBA,
	 * straight alpha, `width` x `height`, drawn into `x`, `y`, `w` x `h` of the group's units. The same
	 * size again is written in place; null pixels draw nothing (and a group's mask is removed).
	 */
	public function setPixels(layer:Int, rgba:Null<Bytes>, width:Int, height:Int, x:Float, y:Float, w:Float, h:Float) {
		_native.SetPixels(layer, rgba != null ? rgba.getData() : null, width, height, x, y, w, h);
	}

	/** Removes every layer. **/
	public function clear() {
		_native.Clear();
	}
}
