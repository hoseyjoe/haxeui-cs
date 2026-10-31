package haxe.ui.backend.cs.native;

import cs.system.Action;
import cs.system.Action_1;
import cs.system.Console;
import cs.system.threading.tasks.TaskCanceledException;
import haxe.ui.backend.cs.net.Net;
import haxe.ui.backend.cs.net.Threading;

/**
 * What `await` does on the UI thread, written out: the callback runs back on the UI thread, once,
 * after the task, without depending on a synchronization context. `failed` gets what `await` would
 * throw: a faulted task's first inner exception, or TaskCanceledException. Nothing either callback
 * throws reaches the dispatcher, which would end the app: it is reported instead.
 *
 * @:nativeGen keeps `then`'s type parameter real: gencs erases one to object on a Haxe class, and
 * no Task<IStorageFile> converts to a Task<object>.
 */
@:nativeGen
class Continue {
	public static function then<T>(task:Task_1<T>, done:T->Void, failed:Dynamic->Void):Void {
		thenVoid(task, () -> done(task.Result), failed);
	}

	public static function thenVoid(task:Task, done:Void->Void, failed:Dynamic->Void):Void {
		var after:Action_1<Task> = function(finished:Task) {
			var back:Action = function() {
				finish(finished, done, failed);
			};
			Dispatcher.UIThread.Post(back, DispatcherPriority.Default);
		};
		task.ContinueWith(after, TaskScheduler.Default);
	}

	static function finish(task:Task, done:Void->Void, failed:Dynamic->Void):Void {
		try {
			if (task.IsFaulted) {
				var inner = task.Exception.InnerException;
				failed(inner != null ? inner : task.Exception);
			} else if (task.IsCanceled) {
				failed(new TaskCanceledException());
			} else {
				done();
			}
		} catch (e:Dynamic) {
			Console.Error.WriteLine("haxeui-cs: a task's callback threw: " + Std.string(e));
		}
	}
}
