package cases;

import cs.system.Exception;
import cs.system.Func_1;
import cs.system.threading.Thread;
import cs.system.threading.ThreadStart;
import haxe.ui.backend.cs.native.Continue;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.backend.cs.net.Net;
import utest.Assert;

/** Going on from a .NET task, as `await` does on the UI thread. **/
class TestContinue extends utest.Test {
	// A task's continuation runs on the thread pool, which then posts to the UI thread.
	function pumpUntil(done:Void->Bool):Void {
		var left = 2000;
		while (!done() && left-- > 0) {
			HeadlessDriver.Pump(1);
			Thread.Sleep(1);
		}
		HeadlessDriver.Pump(2);
	}

	function testDoneGetsTheResult() {
		var source = new TaskCompletionSource_1<String>();
		var got = [];
		var failed = 0;
		Continue.then(source.Task, s -> got.push(s), e -> failed++);
		HeadlessDriver.Pump(2);
		Assert.equals(0, got.length, "nothing before the task ends");
		source.SetResult("x");
		pumpUntil(() -> got.length > 0);
		Assert.equals("x", got.join(","), "the result, once");
		Assert.equals(0, failed);
	}

	function testFailedGetsTheException() {
		var source = new TaskCompletionSource_1<String>();
		var done = 0;
		var messages = [];
		Continue.then(source.Task, s -> done++, e -> messages.push((e : Exception).Message));
		source.SetException(new Exception("bad"));
		pumpUntil(() -> messages.length > 0);
		Assert.equals("bad", messages.join(","), "the inner exception, once");
		Assert.equals(0, done);
	}

	function testCancelledFails() {
		var source = new TaskCompletionSource_1<String>();
		var done = 0;
		var failed = 0;
		Continue.then(source.Task, s -> done++, e -> failed++);
		source.SetCanceled();
		pumpUntil(() -> failed > 0);
		Assert.equals(1, failed);
		Assert.equals(0, done);
	}

	function testThenVoid() {
		var source = new TaskCompletionSource_1<String>();
		var done = 0;
		var failed = 0;
		Continue.thenVoid(source.Task, () -> done++, e -> failed++);
		source.SetResult("x");
		pumpUntil(() -> done > 0);
		Assert.equals(1, done);
		Assert.equals(0, failed);
	}

	function testAlreadyFinished() {
		var source = new TaskCompletionSource_1<String>();
		source.SetResult("x");
		var got = [];
		Continue.then(source.Task, s -> got.push(s), e -> {});
		pumpUntil(() -> got.length > 0);
		Assert.equals("x", got.join(","));
	}

	function testRunsOnTheUiThread() {
		var source = new TaskCompletionSource_1<String>();
		var ui = Thread.CurrentThread;
		var seen:Thread = null;
		Continue.then(source.Task, s -> seen = Thread.CurrentThread, e -> {});
		var start:ThreadStart = function() {
			source.SetResult("x");
		};
		var other = new Thread(start);
		other.Start();
		pumpUntil(() -> seen != null);
		other.Join();
		Assert.isTrue(seen == ui, "back on the UI thread");
	}

	function testRunIsOffTheUiThread() {
		var ui = Thread.CurrentThread;
		var worker:Thread = null;
		var work:Func_1<String> = function():String {
			worker = Thread.CurrentThread;
			return "x";
		};
		var got = [];
		Continue.then(Task.Run(work), s -> got.push(s), e -> {});
		pumpUntil(() -> got.length > 0);
		Assert.equals("x", got.join(","));
		Assert.isFalse(worker == ui, "the work ran elsewhere");
	}

	function testNothingEscapes() {
		var source = new TaskCompletionSource_1<String>();
		var ran = false;
		Continue.then(source.Task, s -> {
			ran = true;
			throw "oops";
		}, e -> {});
		source.SetResult("x");
		pumpUntil(() -> ran);
		Assert.isTrue(ran);

		var bad = new TaskCompletionSource_1<String>();
		var failedRan = false;
		Continue.then(bad.Task, s -> {}, e -> {
			failedRan = true;
			throw "oops";
		});
		bad.SetException(new Exception("bad"));
		pumpUntil(() -> failedRan);
		Assert.isTrue(failedRan, "nor does a throw from failed");
	}
}
