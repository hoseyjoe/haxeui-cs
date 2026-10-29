package haxe.ui.backend.cs.touch;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.native.Native.Host;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.dragdrop.DragManager;
import haxe.ui.events.MouseEvent;
import haxe.ui.tooltips.ToolTipManager;
import haxe.ui.util.Timer;

/**
 * HaxeUI tooltips by long press, for touch screens: a finger has no hover (on Android the hover
 * tooltip is never armed, see macros/TouchPatches), so a finger held still on a component for
 * LongPress.HOLD seconds shows its `tooltip`, through HaxeUI's own ToolTipManager so it looks the
 * same; lifting the finger or moving it hides it, and that release is not a click.
 *
 * heaps-android's LongPressTooltips, on HaxeUI's screen events rather than the Heaps window's, so
 * everything here is in layout units. Drags come first: a press on anything registered with
 * DragManager (or inside one) never arms, and movement past the slop cancels the press or hides a
 * tooltip already up.
 */
class TouchTooltips {
	/** How far a held finger may wander, in layout units. **/
	public static inline var SLOP = 8;
	/** Between the component and its tooltip, in layout units. **/
	public static inline var GAP = 6;

	static var installed = false;
	static var press:Null<LongPress> = null;
	static var target:Null<Component> = null;
	static var showing = false;

	public static function install() {
		if (installed) return;
		installed = true;
		Screen.instance.registerEvent(MouseEvent.MOUSE_DOWN, onDown, haxe.ui.constants.Priority.HIGH);
		Screen.instance.registerEvent(MouseEvent.MOUSE_MOVE, onMove, haxe.ui.constants.Priority.HIGH);
		Screen.instance.registerEvent(MouseEvent.MOUSE_UP, onUp, haxe.ui.constants.Priority.HIGH);
	}

	static function onDown(e:MouseEvent) {
		hide();
		target = tipped(e.screenX, e.screenY);
		if (target == null) {
			if (press != null) press.release();
			return;
		}
		press = new LongPress(SLOP);
		press.press(e.screenX, e.screenY, haxe.Timer.stamp());
		var p = press, x = e.screenX, y = e.screenY;
		Timer.delay(() -> fire(p, x, y), Std.int(LongPress.HOLD * 1000) + 10);
	}

	static function onMove(e:MouseEvent) {
		if (press != null && press.move(e.screenX, e.screenY)) hide();
	}

	static function onUp(e:MouseEvent) {
		if (press != null) press.release();
		var wasShowing = showing;
		hide();
		// The click was eaten, so nothing restyles what was pressed: settle it once HaxeUI has
		// handled the release too.
		if (wasShowing && target != null) {
			var t = target;
			Toolkit.callLater(() -> settle(t));
		}
	}

	/** The hold is up: if it is still this press, held still, show the tooltip and eat the click. **/
	static function fire(p:LongPress, x:Float, y:Float) {
		if (p != press || target == null) return;
		if (!p.poll(haxe.Timer.stamp())) {
			// A timer can fire a little before the press's own timestamp says HOLD is up: look again.
			if (p.pending) Timer.delay(() -> fire(p, x, y), 20);
			return;
		}
		var options = ToolTipManager.instance.getTooltipOptions(target);
		if (options == null) return;
		// Near the screen's bottom showToolTipAt reads the last hover event, which never happens on
		// a touch screen: give it one at the press.
		var at = new MouseEvent(MouseEvent.MOUSE_MOVE);
		at.screenX = x;
		at.screenY = y;
		@:privateAccess ToolTipManager.instance._lastMouseEvent = at;
		ToolTipManager.instance.showToolTipAt(x, y, options);
		showing = true;
		// HaxeUI puts it just below the point, under the finger: once it has been laid out, move it.
		var t = target;
		Toolkit.callLater(() -> place(t));
		Host.SuppressNextClick();
	}

	/** The tooltip above `c`, clear of the finger (below it when there is no room above), and inside the screen across. **/
	static function place(c:Component) {
		var tip = @:privateAccess ToolTipManager.instance._toolTip;
		if (!showing || tip == null) return;
		var above = c.screenTop - (tip.height + GAP);
		tip.top = above >= 0 ? above : c.screenTop + c.height + GAP;
		var maxLeft = Screen.instance.width - tip.width;
		tip.left = Math.max(0, Math.min(tip.left, maxLeft));
	}

	/**
	 * After a long press, `c` and everything round it look as if never pressed. A toggle button
	 * keeps `:down` on release and drops it in its click, which a long press eats; and nothing on a
	 * touch screen ever sends the MOUSE_OUT that clears `:hover`.
	 */
	static function settle(c:Component) {
		while (c != null) {
			var button = Std.downcast(c, haxe.ui.components.Button);
			if (button != null && button.toggle && !button.selected) c.removeClass(":down", true, true);
			c.removeClass(":hover", true, true);
			c = c.parentComponent;
		}
	}

	static function hide() {
		if (!showing) return;
		showing = false;
		ToolTipManager.instance.hideCurrentToolTip();
	}

	/** The component whose tooltip a press at (x, y) would show: the topmost visible one under it,
		or its nearest ancestor with a tooltip. Null when there is none, or when it is draggable. **/
	static function tipped(x:Float, y:Float):Null<Component> {
		var under = Screen.instance.findComponentsUnderPoint(x, y);
		var i = under.length;
		while (i-- > 0) {
			if (!shown(under[i])) continue;
			var tip:Null<Component> = null;
			var c = under[i];
			while (c != null) {
				if (DragManager.instance.isRegisteredDraggable(c)) return null;
				if (tip == null && ToolTipManager.instance.getTooltipOptions(c) != null) tip = c;
				c = c.parentComponent;
			}
			return tip;
		}
		return null;
	}

	static function shown(c:Component):Bool {
		while (c != null) {
			if (c.hidden) return false;
			c = c.parentComponent;
		}
		return true;
	}
}
