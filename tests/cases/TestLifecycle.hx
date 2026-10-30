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
