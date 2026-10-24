package haxe.ui.backend.cs;

import haxe.ui.events.KeyboardEvent;
import haxe.ui.events.MouseEvent;

/** HaxeUI event types against the native EventKind flags (native/UIEvents.cs). **/
class EventMapper {
	public static inline var MOVE = 1;
	public static inline var OVER = 2;
	public static inline var OUT = 4;
	public static inline var DOWN = 8;
	public static inline var UP = 16;
	public static inline var CLICK = 32;
	public static inline var DBL_CLICK = 64;
	public static inline var WHEEL = 128;
	public static inline var RIGHT_DOWN = 256;
	public static inline var RIGHT_UP = 512;
	public static inline var RIGHT_CLICK = 1024;
	public static inline var MIDDLE_DOWN = 2048;
	public static inline var MIDDLE_UP = 4096;
	public static inline var KEY_DOWN = 8192;
	public static inline var KEY_UP = 16384;
	public static inline var MIDDLE_CLICK = 32768;
	public static inline var KEY_PRESS = 65536;

	/** The native kind for a HaxeUI event type, or 0 when it is not an input event. **/
	public static function kindOf(type:String):Int {
		return switch (type) {
			case MouseEvent.MOUSE_MOVE: MOVE;
			case MouseEvent.MOUSE_OVER: OVER;
			case MouseEvent.MOUSE_OUT: OUT;
			case MouseEvent.MOUSE_DOWN: DOWN;
			case MouseEvent.MOUSE_UP: UP;
			case MouseEvent.CLICK: CLICK;
			case MouseEvent.DBL_CLICK: DBL_CLICK;
			case MouseEvent.MOUSE_WHEEL: WHEEL;
			case MouseEvent.RIGHT_MOUSE_DOWN: RIGHT_DOWN;
			case MouseEvent.RIGHT_MOUSE_UP: RIGHT_UP;
			case MouseEvent.RIGHT_CLICK: RIGHT_CLICK;
			case MouseEvent.MIDDLE_MOUSE_DOWN: MIDDLE_DOWN;
			case MouseEvent.MIDDLE_MOUSE_UP: MIDDLE_UP;
			case MouseEvent.MIDDLE_CLICK: MIDDLE_CLICK;
			case KeyboardEvent.KEY_DOWN: KEY_DOWN;
			case KeyboardEvent.KEY_UP: KEY_UP;
			case KeyboardEvent.KEY_PRESS: KEY_PRESS;
			case _: 0;
		}
	}

	public static function typeOf(kind:Int):String {
		return switch (kind) {
			case MOVE: MouseEvent.MOUSE_MOVE;
			case OVER: MouseEvent.MOUSE_OVER;
			case OUT: MouseEvent.MOUSE_OUT;
			case DOWN: MouseEvent.MOUSE_DOWN;
			case UP: MouseEvent.MOUSE_UP;
			case CLICK: MouseEvent.CLICK;
			case DBL_CLICK: MouseEvent.DBL_CLICK;
			case WHEEL: MouseEvent.MOUSE_WHEEL;
			case RIGHT_DOWN: MouseEvent.RIGHT_MOUSE_DOWN;
			case RIGHT_UP: MouseEvent.RIGHT_MOUSE_UP;
			case RIGHT_CLICK: MouseEvent.RIGHT_CLICK;
			case MIDDLE_DOWN: MouseEvent.MIDDLE_MOUSE_DOWN;
			case MIDDLE_UP: MouseEvent.MIDDLE_MOUSE_UP;
			case MIDDLE_CLICK: MouseEvent.MIDDLE_CLICK;
			case KEY_DOWN: KeyboardEvent.KEY_DOWN;
			case KEY_UP: KeyboardEvent.KEY_UP;
			case KEY_PRESS: KeyboardEvent.KEY_PRESS;
			case _: null;
		}
	}

	/** The mask of native kinds for every input type in a listener map. **/
	public static function maskOf(types:Iterator<String>):Int {
		var mask = 0;
		for (type in types) {
			mask |= kindOf(type);
		}
		return mask;
	}
}
