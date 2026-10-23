package haxe.ui.backend;

class TimerImpl {
    private var _timer:haxe.Timer;

    public function new(delay:Int, callback:Void->Void) {
        _timer = new haxe.Timer(delay);
        _timer.run = callback;
    }

    public function stop() {
        _timer.stop();
    }
}
