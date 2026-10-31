package cases;

import haxe.ui.backend.cs.AppLifecycle;
import haxe.ui.backend.cs.BackButton;
import haxe.ui.backend.cs.native.Native;
import utest.Assert;

/** A Haxe event loop with nothing scheduled. **/
private class IdlePump implements IEventsPump {
	public function new() {}

	public function Pump():Float {
		return -1;
	}
}

private class Call implements ICallback {
	final run:Void->Void;

	public function new(run:Void->Void) {
		this.run = run;
	}

	public function Invoke():Void {
		run();
	}
}

private class ThrowingClose implements ICloseListener {
	public function new() {}

	public function OnCloseRequested():Bool {
		throw "oops";
	}
}

private class ThrowingBack implements IBackListener {
	public function new() {}

	public function OnBack():Bool {
		throw "oops";
	}
}

/** Back and going to the background, raised from the host as Android raises them. **/
class TestLifecycle extends utest.Test {
	function teardown() {
		BackButton.clearListeners();
		AppLifecycle.onPause = null;
	}

	function testBackWakesTheEventLoop() {
		// A listener can start a haxe.Timer; an idle loop is only polled every 250 ms.
		BackButton.addListener(() -> true);
		Host.StartEventsPump(new IdlePump()); // the headless host leaves the loop to TestDriver
		settle();
		var before = Host.EventsPumps;
		Host.RaiseBack();
		pumpDispatcher(0.05);
		Assert.isTrue(Host.EventsPumps > before, 'pumps ${Host.EventsPumps}, was $before');
	}

	/** Until the Haxe loop has nothing scheduled and has gone back to its slow idle poll. **/
	static function settle() {
		pumpDispatcher(0.4);
	}

	static function pumpDispatcher(seconds:Float) {
		var end = haxe.Timer.stamp() + seconds;
		while (haxe.Timer.stamp() < end) {
			HeadlessDriver.Pump(1);
			Sys.sleep(0.002);
		}
	}

	function testNoListenersIsUnhandled() {
		Assert.isFalse(Host.RaiseBack());
	}

	function testNewestListenerFirst() {
		var log = [];
		BackButton.addListener(() -> {
			log.push("a");
			return false;
		});
		BackButton.addListener(() -> {
			log.push("b");
			return true;
		});
		Assert.isTrue(Host.RaiseBack());
		Assert.same(["b"], log);
	}

	function testFallsThroughToOlder() {
		var log = [];
		BackButton.addListener(() -> {
			log.push("a");
			return true;
		});
		BackButton.addListener(() -> {
			log.push("b");
			return false;
		});
		Assert.isTrue(Host.RaiseBack());
		Assert.same(["b", "a"], log);
	}

	function testListenerMayRemoveItself() {
		var listener:Void->Bool = null;
		listener = () -> {
			BackButton.removeListener(listener);
			return true;
		};
		BackButton.addListener(listener);
		Assert.isTrue(Host.RaiseBack());
		Assert.isFalse(Host.RaiseBack());
	}

	function testThrowingListenerIsUnhandled() {
		BackButton.addListener(() -> throw "deliberate failure in a back handler");
		Assert.isFalse(Host.RaiseBack());
	}

	function testHaxeThrowIsReported() {
		var ran = false;
		Host.NextFrame(new Call(() -> throw "oops"));
		Host.NextFrame(new Call(() -> ran = true));
		HeadlessDriver.Pump(1);
		Assert.isTrue(ran, "the rest of the frame still runs");

		var close = Host.CloseListener;
		Host.CloseListener = new ThrowingClose();
		Assert.isTrue(Host.AskClose(), "a close handler that throws lets the window close");
		Host.CloseListener = close;

		var back = Host.BackListener;
		Host.BackListener = new ThrowingBack();
		Assert.isFalse(Host.RaiseBack(), "a back handler that throws has not taken back");
		Host.BackListener = back;
	}

	function testPauseCallsHandler() {
		var count = 0;
		AppLifecycle.onPause = () -> count++;
		Host.RaisePause();
		Assert.equals(1, count);
	}

	function testPauseWithoutHandler() {
		Host.RaisePause();
		Assert.pass();
	}

	function testThrowingPauseIsSwallowed() {
		AppLifecycle.onPause = () -> throw "deliberate failure in a pause handler";
		Host.RaisePause();
		Assert.pass();
	}
}
