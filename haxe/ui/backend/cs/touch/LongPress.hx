package haxe.ui.backend.cs.touch;

/**
 * A long press, as touch screens mean it: a finger held still (within `slop` units) for HOLD
 * seconds. Moving past the slop is a scroll or a drag instead, and cancels it for that press.
 * Plain state, fed by TouchTooltips. heaps-android's LongPress, unchanged.
 */
class LongPress {
	public static inline var HOLD = 0.5;

	final slop:Float;
	var down = false;
	var moved = false;
	var fired = false;
	var x0 = 0.0;
	var y0 = 0.0;
	var t0 = 0.0;

	/** Down, still, and not fired yet: a poll that said "not yet" is worth repeating. **/
	public var pending(get, never):Bool;

	public function new(slop:Float)
		this.slop = slop;

	function get_pending():Bool
		return down && !moved && !fired;

	public function press(x:Float, y:Float, t:Float) {
		down = true;
		moved = false;
		fired = false;
		x0 = x;
		y0 = y;
		t0 = t;
	}

	/** True for the move that first takes the finger past the slop (it is a scroll or drag now). **/
	public function move(x:Float, y:Float):Bool {
		if (!down || moved) return false;
		var dx = x - x0, dy = y - y0;
		if (dx * dx + dy * dy <= slop * slop) return false;
		moved = true;
		return true;
	}

	public function release()
		down = false;

	/** True once per press, when it has been held still for HOLD seconds by `t`. **/
	public function poll(t:Float):Bool {
		if (!down || moved || fired || t - t0 < HOLD) return false;
		fired = true;
		return true;
	}
}
