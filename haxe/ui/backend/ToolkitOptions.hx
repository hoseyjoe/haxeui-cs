package haxe.ui.backend;

/** What `new HaxeUIApp(options)` can ask of the desktop window (headless runs keep 800x600). **/
typedef ToolkitOptions = {
    @:optional var width:Int;
    @:optional var height:Int;
    @:optional var title:String;
}
