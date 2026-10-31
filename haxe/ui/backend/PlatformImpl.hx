package haxe.ui.backend;

class PlatformImpl extends PlatformBase {
    public override function getSystemLocale():String {
        return cs.system.globalization.CultureInfo.CurrentUICulture.Name;
    }
}
