package haxe.ui.backend.cs;

import haxe.ui.backend.cs.native.Native.ICallback;

/** Adapts Haxe functions to the callback interfaces the C# side calls. **/
class Callbacks {
	public static function callback(fn:Void->Void):ICallback {
		return new FunctionCallback(fn);
	}
}

private class FunctionCallback implements ICallback {
	var fn:Void->Void;

	public function new(fn:Void->Void) {
		this.fn = fn;
	}

	public function Invoke():Void {
		fn();
	}
}
