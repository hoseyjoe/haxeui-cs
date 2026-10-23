package cases;

/** Small helpers for tests that read rendered pixels (ARGB ints). **/
class Pixels {
	/** R + G + B: 0 is black, 765 is white. **/
	public static function bright(argb:Int):Int {
		return ((argb >> 16) & 0xFF) + ((argb >> 8) & 0xFF) + (argb & 0xFF);
	}
}
