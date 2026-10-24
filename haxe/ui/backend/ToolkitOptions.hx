package haxe.ui.backend;

/** What `new HaxeUIApp(options)` can ask of the desktop window (headless runs keep 800x600). **/
typedef ToolkitOptions = {
    @:optional var width:Int;
    @:optional var height:Int;
    @:optional var title:String;
    /** Whether the user can resize the window (default true). **/
    @:optional var resizable:Bool;
    @:optional var minWidth:Int;
    @:optional var minHeight:Int;
    /** Open maximized. **/
    @:optional var maximized:Bool;
}
