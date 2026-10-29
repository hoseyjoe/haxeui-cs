package haxe.ui.backend.cs;

import haxe.ui.events.EventType;
import haxe.ui.events.UIEvent;

/**
 * A click on a link (`<a href="...">`) in a component's `htmlText`, dispatched on that component.
 * html5 would follow the link itself; here nothing happens unless the app listens:
 *
 * ```haxe
 * label.htmlText = 'See <a href="notes.html#3">note 3</a>.';
 * label.registerEvent(TextLinkEvent.LINK, e -> open(e.href));
 * ```
 */
class TextLinkEvent extends UIEvent {
	public static final LINK:EventType<TextLinkEvent> = EventType.name("textlink");

	/** The link's `href`, entities decoded. **/
	public var href:String;

	/** Which link of the text, in document order (TextDisplayImpl.linkHref). **/
	public var index:Int = -1;

	public function new(type:EventType<TextLinkEvent>) {
		super(type);
	}

	public override function clone():TextLinkEvent {
		var c = new TextLinkEvent(this.type);
		c.type = this.type;
		c.target = this.target;
		c.href = this.href;
		c.index = this.index;
		postClone(c);
		return c;
	}
}
