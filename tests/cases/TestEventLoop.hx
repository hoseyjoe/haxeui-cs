package cases;

import haxe.ui.Toolkit;
import haxe.ui.backend.cs.TestDriver;
import haxe.ui.backend.cs.native.Native.HeadlessDriver;
import haxe.ui.util.Timer;
import utest.Assert;

/** Timers and deferred calls, driven by Avalonia's dispatcher. **/
class TestEventLoop extends utest.Test {
	function testCallLaterRunsOnPump() {
		var hit = 0;
		Toolkit.callLater(() -> hit++);
		Assert.equals(0, hit);
		TestDriver.pump();
		Assert.equals(1, hit);
	}

	function testSelfRepostingCallLaterRunsOncePerFrame() {
		// HaxeUI's animations re-post a callLater from inside it (Actuator.processCallbacks),
		// expecting "next frame" as requestAnimationFrame gives on html5 — never a busy loop.
		var steps = 0;
		var running = true;
		function step() {
			steps++;
			if (running) {
				Toolkit.callLater(step);
			}
		}
		Toolkit.callLater(step);
		TestDriver.pump(3);
		running = false;
		TestDriver.pump(2);
		Assert.isTrue(steps >= 3 && steps <= 10, 'steps $steps');
	}

	function testThrowingCallLaterKeepsTheRestOfItsFrame() {
		// as with a browser's requestAnimationFrame callbacks: one failing does not cancel the others
		var ran = false;
		Toolkit.callLater(() -> throw "deliberate failure in a callLater");
		Toolkit.callLater(() -> ran = true);
		TestDriver.pump();
		Assert.isTrue(ran);
	}

	function testUiTimerFires() {
		var fired = 0;
		var timer = new Timer(20, () -> fired++);
		pumpFor(120, () -> TestDriver.pump());
		Assert.isTrue(fired >= 2, 'fired $fired times');
		timer.stop();
		var afterStop = fired;
		pumpFor(60, () -> TestDriver.pump());
		Assert.equals(afterStop, fired);
	}

	function testUiTimerRunsOnDispatcherAlone() {
		// Only Avalonia's dispatcher runs here, as on the desktop: no Haxe event-loop pumping.
		var fired = 0;
		var timer = new Timer(20, () -> fired++);
		pumpFor(120, () -> HeadlessDriver.Pump(1));
		timer.stop();
		Assert.isTrue(fired >= 2, 'fired $fired times');
	}

	function testHaxeTimerDelayFires() {
		var fired = false;
		haxe.Timer.delay(() -> fired = true, 10);
		pumpFor(80, () -> TestDriver.pump());
		Assert.isTrue(fired);
	}

	static function pumpFor(milliseconds:Int, pump:Void->Void) {
		var end = haxe.Timer.stamp() + milliseconds / 1000;
		while (haxe.Timer.stamp() < end) {
			pump();
			Sys.sleep(0.005);
		}
	}
}
