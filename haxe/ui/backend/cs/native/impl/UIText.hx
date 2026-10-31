package haxe.ui.backend.cs.native.impl;

import cs.NativeArray;
import cs.system.Double;
import cs.system.Environment;
import cs.system.Exception;
import cs.system.UInt32;
import cs.system.globalization.CultureInfo;
import cs.system.globalization.NumberStyles;
import cs.system.text.regularexpressions.Match;
import cs.system.text.regularexpressions.Regex;
import haxe.ui.backend.cs.native.Native.UIPanel;
import haxe.ui.backend.cs.native.impl.ColorMatrix;
import haxe.ui.backend.cs.native.impl.UIFonts;
import haxe.ui.backend.cs.net.Avalonia;
import haxe.ui.backend.cs.net.Controls;
import haxe.ui.backend.cs.net.Media;
import haxe.ui.backend.cs.net.Net;

@:native("HaxeUICs.UITextRunStyle")
@:nativeGen
class UITextRunStyle {
	public var Bold = false;
	public var Italic = false;
	public var Underline = false;
	public var Strike = false;
	public var Color:Null<UInt> = null;
	public var Size:Null<Float> = null;
	public var Face:String = null;
	public var Link = -1;

	public function new() {}

	public function Copy():UITextRunStyle {
		var copy = new UITextRunStyle();
		copy.Bold = Bold;
		copy.Italic = Italic;
		copy.Underline = Underline;
		copy.Strike = Strike;
		copy.Color = Color;
		copy.Size = Size;
		copy.Face = Face;
		copy.Link = Link;
		return copy;
	}
}

/**
 * A HaxeUI text display: a TextBlock HaxeUI positions and sizes itself, which can also report
 * the size its text needs (unbounded, or wrapped at a width).
 */
@:native("HaxeUICs.UIText")
@:nativeGen
class UIText extends TextBlock implements IColorFiltered {
	var _matrix:NativeArray<Single>;
	var _color:UInt = 0xFF000000;
	var _shadowX = 0.0;
	var _shadowY = 0.0;
	var _shadowBlur = 0.0;
	var _shadowColor:UInt = 0;

	public function SetEffectiveColorMatrix(matrix:NativeArray<Single>):Void {
		_matrix = matrix;
		SetColor(_color);
		SetShadow(_shadowX, _shadowY, _shadowBlur, _shadowColor);
		if (_html != null) {
			BuildInlines();
		}
	}

	// ---- HTML text: a small subset, as runs of styled text ----

	var _html:String;

	/**
	 * Shows HTML text: b/strong, i/em, u, s/strike/del, br, font (color, size, face),
	 * span style="color: ..." and a href. Other tags are dropped and their text kept; entities
	 * are decoded and whitespace collapses as in HTML. Null goes back to plain Text.
	 */
	public function SetHtml(html:String):Void {
		if (html == _html) {
			return;
		}
		_html = html;
		if (html != null) {
			BuildInlines();
		} else if (_linkHrefs.length > 0) {
			_linkHrefs.resize(0);
			_linkStarts.resize(0);
			_linkLengths.resize(0);
			_linkIndexes.resize(0);
		}
	}

	static final Attribute = new Regex("([\\w-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))");
	static final Space = new Regex("\\s+");
	static final StyleColour = new Regex("(?:^|;)\\s*color\\s*:\\s*([^;]+)");
	static final HtmlSizes:Array<Float> = [10, 13, 16, 18, 24, 32, 48];

	// ---- links: a href, as ranges of the laid-out text ----

	final _linkHrefs = new Array<String>();
	final _linkStarts = new Array<Int>();
	final _linkLengths = new Array<Int>();
	final _linkIndexes = new Array<Int>();

	/** The links in the HTML text, in document order. */
	@:property public var LinkCount(get, never):Int;

	function get_LinkCount():Int {
		return _linkHrefs.length;
	}

	public function LinkHref(index:Int):String {
		return index >= 0 && index < _linkHrefs.length ? _linkHrefs[index] : null;
	}

	/**
	 * Every link's areas, in this text's own units, as [link, x, y, width, height] for each
	 * piece of a line a link covers: a link broken over two lines has two.
	 */
	public function LinkRects():NativeArray<Float> {
		var rects = new Array<Float>();
		if (_linkStarts.length > 0) {
			var layout = CurrentLayout();
			for (i in 0..._linkStarts.length) {
				var pieces = layout.HitTestTextRange(_linkStarts[i], _linkLengths[i]).GetEnumerator();
				while (pieces.MoveNext()) {
					var r:Rect = pieces.Current;
					if (r.Width <= 0) {
						continue;
					}
					rects.push(_linkIndexes[i]);
					rects.push(r.X);
					rects.push(r.Y);
					rects.push(r.Width);
					rects.push(r.Height);
				}
				pieces.Dispose();
			}
		}
		var result = new NativeArray<Float>(rects.length);
		for (i in 0...rects.length) {
			result[i] = rects[i];
		}
		return result;
	}

	/** The link at a point in this text's own units, or -1. */
	public function LinkAt(x:Float, y:Float):Int {
		var rects = LinkRects();
		var i = 0;
		while (i < rects.Length) {
			if (x >= rects[i + 1] && x < rects[i + 1] + rects[i + 3] && y >= rects[i + 2] && y < rects[i + 2] + rects[i + 4]) {
				return Std.int(rects[i]);
			}
			i += 5;
		}
		return -1;
	}

	/** Each laid-out line's top and height, in this text's own units, as [top, height, ...]. */
	public function LineBoxes():NativeArray<Float> {
		var layout = CurrentLayout();
		var lines = layout.TextLines;
		var all:IReadOnlyCollection<TextLine> = lines;
		var boxes = new NativeArray<Float>(all.Count * 2);
		var top = 0.0;
		for (i in 0...all.Count) {
			var line:TextLine = lines[i];
			boxes[i * 2] = top;
			boxes[i * 2 + 1] = line.Height;
			top += line.Height;
		}
		return boxes;
	}

	/**
	 * The text laid out at the width HaxeUI gave it. MeasureText lays it out at the width it
	 * asks about, and Avalonia's own pass may not have run since, so measure again first.
	 */
	function CurrentLayout():TextLayout {
		Measure(new Size(Math.isNaN(Width) ? Math.POSITIVE_INFINITY : Width, Math.POSITIVE_INFINITY));
		return TextLayout;
	}

	/** An attribute match's value, in whichever of its three quotings it came. */
	static function AttributeValue(m:Match):String {
		return m.Groups[2].Success ? m.Groups[2].Value : m.Groups[3].Success ? m.Groups[3].Value : m.Groups[4].Value;
	}

	function BuildInlines():Void {
		var inlines = new InlineCollection();
		var offset = 0;
		_linkHrefs.resize(0);
		_linkStarts.resize(0);
		_linkLengths.resize(0);
		_linkIndexes.resize(0);
		var style = new UITextRunStyle();
		var openTags = new Array<String>();
		var openStyles = new Array<UITextRunStyle>();
		var text = "";
		var html = _html;
		function flush() {
			if (text.length == 0) {
				return;
			}
			var words = WebUtility.HtmlDecode(Space.Replace(text, " "));
			text = "";
			if (words.length == 0) {
				return;
			}
			inlines.Add(MakeRun(words, style));
			if (style.Link >= 0) {
				_linkStarts.push(offset);
				_linkLengths.push(words.length);
				_linkIndexes.push(style.Link);
			}
			offset += words.length;
		}
		var i = 0;
		while (i < html.length) {
			var lt = html.indexOf("<", i);
			var gt = lt < 0 ? -1 : html.indexOf(">", lt);
			if (lt < 0 || gt < 0) {
				text += html.substring(i, html.length);
				break;
			}
			text += html.substring(i, lt);
			flush();
			var tag = StringTools.trim(html.substring(lt + 1, gt));
			i = gt + 1;
			if (StringTools.startsWith(tag, "/")) {
				var name = StringTools.trim(tag.substr(1)).toLowerCase();
				var k = openTags.length - 1;
				while (k >= 0) {
					if (openTags[k] == name) {
						style = openStyles[k];
						openTags.splice(k, openTags.length - k);
						openStyles.splice(k, openStyles.length - k);
						break;
					}
					k--;
				}
				continue;
			}
			var body = tag;
			while (StringTools.endsWith(body, "/")) {
				body = body.substring(0, body.length - 1);
			}
			var space = FirstSpace(body);
			var tagName = (space < 0 ? body : body.substring(0, space)).toLowerCase();
			if (tagName == "br") {
				inlines.Add(new LineBreak());
				offset += Environment.NewLine.length; // what Avalonia's LineBreak puts in the text
				continue;
			}
			var next = style.Copy();
			var attributes = space < 0 ? "" : body.substr(space + 1);
			switch (tagName) {
				case "b" | "strong":
					next.Bold = true;
				case "i" | "em":
					next.Italic = true;
				case "u":
					next.Underline = true;
				case "s" | "strike" | "del":
					next.Strike = true;
				case "font":
					var matches = Attribute.Matches(attributes);
					for (n in 0...matches.Count) {
						var m:Match = cast matches[n];
						var value = AttributeValue(m);
						switch (m.Groups[1].Value.toLowerCase()) {
							case "color":
								var colour = ParseColor(value);
								if (colour != null) {
									next.Color = colour;
								}
							case "face":
								next.Face = value;
							case "size":
								var size = 0.0;
								if (Double.TryParse(StringTools.replace(value, "px", ""), NumberStyles.Float, CultureInfo.InvariantCulture, size)) {
									next.Size = size >= 1 && size <= 7 && !StringTools.endsWith(value, "px") ? HtmlSizes[Std.int(size) - 1] : size;
								}
							case _:
						}
					}
				case "span":
					var matches = Attribute.Matches(attributes);
					for (n in 0...matches.Count) {
						var m:Match = cast matches[n];
						if (m.Groups[1].Value.toLowerCase() != "style") {
							continue;
						}
						var found = StyleColour.Match(AttributeValue(m));
						if (found.Success) {
							var colour = ParseColor(StringTools.trim(found.Groups[1].Value));
							if (colour != null) {
								next.Color = colour;
							}
						}
					}
				case "a":
					// As a browser's default style: blue and underlined, until a font tag inside says otherwise.
					var href:String = null;
					var matches = Attribute.Matches(attributes);
					for (n in 0...matches.Count) {
						var m:Match = cast matches[n];
						if (m.Groups[1].Value.toLowerCase() == "href") {
							href = WebUtility.HtmlDecode(AttributeValue(m));
						}
					}
					if (href != null) { // an anchor that links nowhere is plain text
						next.Link = _linkHrefs.length;
						_linkHrefs.push(href);
						var blue:UInt = 0xFF0000EE;
						next.Color = blue;
						next.Underline = true;
					}
				default:
					continue; // unknown: dropped, its text kept
			}
			openTags.push(tagName);
			openStyles.push(style);
			style = next;
		}
		flush();
		Inlines = inlines;
		if (Std.isOfType(Parent, UIPanel)) {
			(cast Parent : UIPanel).LinksChanged();
		}
	}

	/** Where the first of a space, tab or line break is, or -1. */
	static function FirstSpace(s:String):Int {
		for (i in 0...s.length) {
			var c = s.charCodeAt(i);
			if (c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code) {
				return i;
			}
		}
		return -1;
	}

	function MakeRun(text:String, style:UITextRunStyle):Run {
		var run = new Run(text);
		if (style.Bold) {
			run.FontWeight = Bold;
		}
		if (style.Italic) {
			run.FontStyle = Italic;
		}
		if (style.Underline || style.Strike) {
			run.TextDecorations = UIFonts.Decorations(style.Underline, style.Strike);
		}
		if (style.Color != null) {
			var argb:UInt = style.Color;
			run.Foreground = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)), 1.0);
		}
		if (style.Size != null) {
			run.FontSize = style.Size;
		}
		if (style.Face != null && style.Face != "") {
			run.FontFamily = UIFonts.ResolveFamily(style.Face);
		}
		return run;
	}

	static function ParseColor(value:String):Null<UInt> {
		var hex = StringTools.trim(value);
		while (StringTools.startsWith(hex, "#")) {
			hex = hex.substr(1);
		}
		if (hex.length == 3) {
			var r = hex.charAt(0), g = hex.charAt(1), b = hex.charAt(2);
			hex = r + r + g + g + b + b;
		}
		var rgb:UInt = 0;
		if (hex.length == 6 && UInt32.TryParse(hex, NumberStyles.HexNumber, null, rgb)) {
			var opaque:UInt = 0xFF000000;
			return opaque | rgb;
		}
		return null;
	}

	public var MeasuredWidth(default, null):Float = 0;
	public var MeasuredHeight(default, null):Float = 0;

	/** How many times MeasureText has actually laid the text out (for the tests). */
	public var MeasureLayouts(default, null):Int = 0;

	public var IsBold(get, never):Bool;

	function get_IsBold():Bool {
		return (cast FontWeight : Int) >= 700;
	}

	public function new() {
		super();
		IsHitTestVisible = false;
		TextWrapping = NoWrap;
	}

	public function SetFont(family:String, size:Float, bold:Bool, italic:Bool, underline:Bool, strikethrough:Bool):Void {
		FontFamily = UIFonts.ResolveFamily(family);
		FontSize = size > 0 ? size : 13;
		FontWeight = bold ? Bold : Normal;
		FontStyle = italic ? Italic : Normal;
		TextDecorations = UIFonts.Decorations(underline, strikethrough);
	}

	public function SetColor(argb:UInt):Void {
		_color = argb;
		Foreground = new SolidColorBrush(Color.FromUInt32(ColorMatrix.Apply(_matrix, argb)), 1.0);
	}

	/** 0 left, 1 center, 2 right, 3 justify. */
	public function SetAlign(align:Int):Void {
		TextAlignment = align == 1 ? Center : align == 2 ? Right : align == 3 ? Justify : Left;
	}

	/** A shadow of the glyphs (haxeui-cs's text-shadow); argb 0 removes it. */
	public function SetShadow(dx:Float, dy:Float, blur:Float, argb:UInt):Void {
		_shadowX = dx;
		_shadowY = dy;
		_shadowBlur = blur;
		_shadowColor = argb;
		var mapped:UInt = argb == 0 ? 0 : ColorMatrix.Apply(_matrix, argb);
		if (mapped == 0) {
			Effect = null;
			return;
		}
		var shadow = new DropShadowEffect();
		shadow.OffsetX = dx;
		shadow.OffsetY = dy;
		shadow.BlurRadius = Math.max(0, blur);
		var opaque:UInt = 0xFF000000;
		shadow.Color = Color.FromUInt32(mapped | opaque);
		shadow.Opacity = ((mapped >> 24) & 0xFF) / 255.0;
		Effect = shadow;
	}

	/** The height of every line (haxeui-cs's line-height); 0 or less goes back to the font's own. */
	public function SetLineHeight(height:Float):Void {
		LineHeight = height > 0 ? height : Math.NaN;
	}

	public function SetWrap(wrap:Bool):Void {
		TextWrapping = wrap ? Wrap : NoWrap;
	}

	/** Sets position and size; NaN leaves that value as it was. */
	public function SetBounds(left:Float, top:Float, width:Float, height:Float):Void {
		if (!Math.isNaN(left)) {
			Canvas.SetLeft(this, left);
		}
		if (!Math.isNaN(top)) {
			Canvas.SetTop(this, top);
		}
		if (!Math.isNaN(width)) {
			Width = Math.max(0, width);
		}
		if (!Math.isNaN(height)) {
			Height = Math.max(0, height);
		}
	}

	/**
	 * Measures the text as it would lay out within maxWidth (0 or less: no limit), ignoring the
	 * size HaxeUI last gave it. Empty text measures as one line, so an empty label keeps its height.
	 */
	public function MeasureText(maxWidth:Float):Void {
		if (maxWidth <= 0) {
			maxWidth = 0;
		}
		if (maxWidth == _askedA) {
			MeasuredWidth = _widthA;
			MeasuredHeight = _heightA;
			return;
		}
		if (maxWidth == _askedB) {
			MeasuredWidth = _widthB;
			MeasuredHeight = _heightB;
			return;
		}
		MeasureLayouts++;
		_measuring = true;
		try {
			LayOutToMeasure(maxWidth);
		} catch (e:Exception) {
			_measuring = false;
			throw e;
		}
		_measuring = false;
		_askedA = _askedB;
		_widthA = _widthB;
		_heightA = _heightB;
		_askedB = maxWidth;
		_widthB = MeasuredWidth;
		_heightB = MeasuredHeight;
	}

	/**
	 * Measures one line of no width, in this font and line height, without laying the text out:
	 * the answer for a text that will wrap at a width it hasn't been given yet.
	 */
	public function MeasureOneLine():Void {
		var typeface = new Typeface(FontFamily, FontStyle, FontWeight, FontStretch.Normal);
		var line = new TextLayout("|", typeface, FontSize, null, Left, NoWrap, null, null, LeftToRight, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY,
			LineHeight, 0, 0, null, null);
		Scope.run(line, () -> {
			MeasuredWidth = 0;
			MeasuredHeight = Math.fceil(line.Height);
		});
	}

	// ---- what MeasureText last answered: shaping a paragraph is slow, and HaxeUI's layout asks
	// the same question many times over, with no limit and at the one width ----

	var _askedA = Math.NaN;
	var _widthA = 0.0;
	var _heightA = 0.0;
	var _askedB = Math.NaN;
	var _widthB = 0.0;
	var _heightB = 0.0;
	var _measuring = false;

	function ForgetMeasured():Void {
		_askedA = Math.NaN;
		_askedB = Math.NaN;
	}

	@:protected override function OnPropertyChanged(change:AvaloniaPropertyChangedEventArgs):Void {
		super.OnPropertyChanged(change);
		if (_measuring) {
			return;
		}
		// Anything else might change what the text measures; these never do.
		var p = change.Property;
		if (p == Layoutable.WidthProperty || p == Layoutable.HeightProperty || p == Visual.BoundsProperty || p == TextBlock.ForegroundProperty
			|| p == Canvas.LeftProperty || p == Canvas.TopProperty) {
			return;
		}
		ForgetMeasured();
	}

	@:protected override function OnAttachedToVisualTree(e:VisualTreeAttachmentEventArgs):Void {
		super.OnAttachedToVisualTree(e);
		ForgetMeasured(); // layout rounds to the display it is now on
	}

	function LayOutToMeasure(maxWidth:Float):Void {
		var width = Width;
		var height = Height;
		var available = new Size(maxWidth > 0 ? maxWidth : Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		if (_html != null) {
			Width = Math.NaN;
			Height = Math.NaN;
			Measure(available);
			MeasuredWidth = Math.fceil(DesiredSize.Width);
			MeasuredHeight = Math.fceil(DesiredSize.Height);
			Width = width;
			Height = height;
			return;
		}
		var text = Text;
		var empty = text == null || text == "";
		if (empty) {
			Text = "|";
		}
		Width = Math.NaN;
		Height = Math.NaN;
		Measure(available);
		MeasuredWidth = empty ? 0 : Math.fceil(DesiredSize.Width);
		MeasuredHeight = Math.fceil(DesiredSize.Height);
		Text = text;
		Width = width;
		Height = height;
	}
}
