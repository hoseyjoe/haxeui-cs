@:native("OwnNative.Greeting")
private extern class Greeting {
	static function Say():String;
}

/** An hxc app with C# of its own, which check.sh writes. **/
class Own {
	static function main() {
		Sys.println(Greeting.Say());
	}
}
