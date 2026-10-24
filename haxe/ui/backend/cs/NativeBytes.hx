package haxe.ui.backend.cs;

import haxe.io.Bytes;

/**
 * Bytes for the C# side, exactly as many as there are. On C#, `Bytes.getData()` is the backing
 * array, which can be longer than the bytes (a resource's is padded): an image decoder stops
 * at its own end marker, but an SVG's XML parser reads the padding and fails.
 */
class NativeBytes {
	public static function of(bytes:Bytes):haxe.io.BytesData {
		var data = bytes.getData();
		return data.length == bytes.length ? data : bytes.sub(0, bytes.length).getData();
	}
}
