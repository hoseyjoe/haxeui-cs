package cases;

/** Small helpers for tests that read rendered pixels (ARGB ints). **/
class Pixels {
	/** R + G + B: 0 is black, 765 is white. **/
	public static function bright(argb:Int):Int {
		return ((argb >> 16) & 0xFF) + ((argb >> 8) & 0xFF) + (argb & 0xFF);
	}

	public static function countWhere(pixels:Array<Int>, test:Int->Bool):Int {
		var n = 0;
		for (p in pixels) {
			if (test(p)) {
				n++;
			}
		}
		return n;
	}

	/** The longest run of consecutive pixels passing `test` in one row of a width-wide region. **/
	public static function longestRun(pixels:Array<Int>, width:Int, row:Int, test:Int->Bool):Int {
		var best = 0, run = 0;
		for (x in 0...width) {
			if (test(pixels[row * width + x])) {
				run++;
				if (run > best) {
					best = run;
				}
			} else {
				run = 0;
			}
		}
		return best;
	}
}
