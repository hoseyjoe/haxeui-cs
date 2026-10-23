package haxe.ui.backend;

class PlatformImpl extends PlatformBase {
    public override function getSystemLocale():String {
        return cs.Syntax.code("global::System.Globalization.CultureInfo.CurrentUICulture.Name");
    }
}
