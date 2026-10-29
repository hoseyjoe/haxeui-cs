package cases;

import haxe.ui.backend.cs.AppLifecycle;
import haxe.ui.backend.cs.BackButton;
import haxe.ui.backend.cs.native.Native;
import utest.Assert;

/** Back and going to the background, raised from the host as Android raises them. **/
class TestLifecycle extends utest.Test {
	function teardown() {
		BackButton.clearListeners();
		AppLifecycle.onPause = null;
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
