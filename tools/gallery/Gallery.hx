import haxe.ui.ComponentBuilder;
import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.components.Label;
import haxe.ui.containers.Grid;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.validation.ValidationManager;
#if haxeui_cs
import haxe.ui.backend.cs.TestDriver;
#end

typedef Entry = {name:String, make:Void->Component};

/**
 * The parity gallery: the same pages built for haxeui-cs (headless) and for
 * html5, the reference. Every component class core has, then hand-made samples
 * with data, then style properties, 24 to a page.
 *
 * cs: writes tools/gallery/out/results[-dark].txt and page<N>[-dark].png.
 * html5: web/index.html?page=N&dark=1 shows one page; compare.py photographs
 * those and puts each under its cs twin (tools/gallery/out/compare).
 */
class Gallery {
	/** Every class in core's haxe.ui.components and haxe.ui.containers packages. **/
	static var CLASSES:Array<String> = ClassList.all();

	static inline var PER_PAGE = 24;

	/** Classes in the walk that are not components you can put on screen. **/
	static var NOT_COMPONENTS = [
		"haxe.ui.containers.IVirtualContainer",
		"haxe.ui.containers.dialogs.Dialogs",
		"haxe.ui.containers.dialogs.OpenFileDialog",
		"haxe.ui.containers.dialogs.OpenFolderDialog",
		"haxe.ui.containers.dialogs.SaveFileDialog",
		"haxe.ui.containers.windows.WindowEvent",
		"haxe.ui.containers.windows.WindowManager",
	];

	static function main() {
		#if haxeui_cs
		var app = new HaxeUIApp({width: 1440, height: 900});
		#else
		var app = new HaxeUIApp();
		#end
		app.ready(function() {
			Toolkit.styleSheet.parse("@keyframes gallerypulse { 0% { opacity: 1; } 100% { opacity: 0.2; } }");
			#if haxeui_cs
			runCs(Sys.args().indexOf("--dark") != -1);
			#else
			var q = js.Browser.location.search;
			var dark = q.indexOf("dark=1") != -1;
			var r = ~/page=(\d+)/;
			var page = r.match(q) ? Std.parseInt(r.matched(1)) : 0;
			if (dark) Toolkit.theme = "dark";
			var list = entries();
			var root = buildPage(list, page, dark, null);
			Screen.instance.addComponent(root);
			app.start();
			#end
		});
	}

	static function entries():Array<Entry> {
		var list:Array<Entry> = [];
		var names = CLASSES.copy();
		names.sort(Reflect.compare);
		for (name in names) {
			if (NOT_COMPONENTS.indexOf(name) != -1) continue;
			if (name == "haxe.ui.containers.TreeViewNode") {
				list.push({name: name, make: function() {
					var tv = new TreeView();
					tv.width = 150;
					tv.height = 90;
					var n = tv.addNode({text: "TreeViewNode"});
					n.addNode({text: "child"});
					n.expanded = true;
					return tv;
				}});
				continue;
			}
			list.push({name: name, make: function() {
				var cls = Type.resolveClass(name);
				if (cls == null) throw "NO CLASS";
				var c:Component = Type.createInstance(cls, []);
				try c.text = name.substr(name.lastIndexOf(".") + 1) catch (_:Dynamic) {}
				return c;
			}});
		}
		for (s in samples()) list.push(s);
		return list;
	}

	static function samples():Array<Entry> {
		return [
			{name: "sample: listview", make: () -> ComponentBuilder.fromString('<listview width="150" height="90" selectedIndex="1"><data><item text="Apple" /><item text="Banana" /><item text="Cherry" /><item text="Damson" /></data></listview>')},
			{name: "sample: dropdown", make: () -> ComponentBuilder.fromString('<dropdown width="140" text="Pick"><data><item text="One" /><item text="Two" /></data></dropdown>')},
			{name: "sample: tableview", make: () -> ComponentBuilder.fromString('<tableview width="155" height="90"><header width="100%"><column id="a" text="Name" width="80" /><column id="b" text="Qty" width="60" /></header><data><item a="Nails" b="12" /><item a="Glue" b="3" /></data></tableview>')},
			{name: "sample: treeview", make: () -> {
				var tv = new TreeView();
				tv.width = 150;
				tv.height = 90;
				var a = tv.addNode({text: "Folder"});
				a.addNode({text: "File one"});
				a.addNode({text: "File two"});
				a.expanded = true;
				tv.addNode({text: "Other"});
				return tv;
			}},
			{name: "sample: tabview", make: () -> ComponentBuilder.fromString('<tabview width="155" height="90"><box text="First"><label text="Page one" /></box><box text="Second"><label text="Page two" /></box></tabview>')},
			{name: "sample: accordion", make: () -> ComponentBuilder.fromString('<accordion width="150" height="95"><box text="Section A"><label text="aaa" /></box><box text="Section B"><label text="bbb" /></box></accordion>')},
			{name: "sample: menubar", make: () -> ComponentBuilder.fromString('<menubar width="150"><menu text="File"><menuitem text="Open" shortcutText="Ctrl+O" /><menuseparator /><menucheckbox text="Wrap" selected="true" /></menu><menu text="Edit" /></menubar>')},
			{name: "sample: buttonbar", make: () -> ComponentBuilder.fromString('<buttonbar selectedIndex="0"><button text="L" /><button text="M" /><button text="R" /></buttonbar>')},
			{name: "sample: button icons", make: () -> ComponentBuilder.fromString('<vbox><button text="Left icon" icon="haxeui-core/styles/default/haxeui_tiny.png" /><button text="Top" icon="haxeui-core/styles/default/haxeui_tiny.png" iconPosition="top" /></vbox>')},
			{name: "sample: disabled", make: () -> ComponentBuilder.fromString('<vbox disabled="true"><button text="Disabled" /><checkbox text="Disabled" selected="true" /><textfield text="Disabled" /></vbox>')},
			{name: "sample: slider value", make: () -> ComponentBuilder.fromString('<vbox width="150"><slider pos="40" width="140" /><progress pos="60" width="140" /><horizontalrange start="20" end="70" width="140" /></vbox>')},
			{name: "sample: frame + form", make: () -> ComponentBuilder.fromString('<frame text="Frame" width="150"><grid columns="2"><label text="Name" /><textfield width="70" /><label text="Age" /><numberstepper pos="3" /></grid></frame>')},
			{name: "sample: splitter", make: () -> ComponentBuilder.fromString('<horizontalsplitter width="150" height="80"><box width="50%" height="100%" style="background-color:#c0e0ff" /><box width="50%" height="100%" style="background-color:#ffe0c0" /></horizontalsplitter>')},
			{name: "sample: scrollview", make: () -> ComponentBuilder.fromString('<scrollview width="150" height="90"><vbox><label text="A long line of text that must scroll sideways" /><label text="2" /><label text="3" /><label text="4" /><label text="5" /><label text="6" /></vbox></scrollview>')},
			{name: "sample: dialog", make: () -> ComponentBuilder.fromString('<dialog title="Dialog" width="150"><label text="Body" /></dialog>')},
			{name: "sample: window", make: () -> ComponentBuilder.fromString('<window title="Window" width="150" height="90"><label text="Body" /></window>')},
			{name: "sample: textarea wrap", make: () -> ComponentBuilder.fromString('<textarea width="150" height="90" text="A textarea with enough words in it to wrap across several lines, and then some more." />')},
			{name: "sample: label wrap", make: () -> ComponentBuilder.fromString('<label width="150" text="A label with word wrap on, long enough to need three lines at this width." wordWrap="true" />')},

			{name: "style: gradient v/h", make: () -> ComponentBuilder.fromString('<hbox><box width="60" height="60" style="background-color:#ff0000;background-color-end:#0000ff;background-gradient-style:vertical" /><box width="60" height="60" style="background-color:#ff0000;background-color-end:#0000ff;background-gradient-style:horizontal" /></hbox>')},
			{name: "style: radius + border", make: () -> ComponentBuilder.fromString('<hbox><box width="60" height="60" style="background-color:#80c080;border:3px solid #206020;border-radius:12px" /><box width="60" height="60" style="background-color:#80c080;border-top:4px solid #ff0000;border-bottom:4px solid #0000ff;border-left:1px solid #000000" /></hbox>')},
			{name: "style: per-corner radius", make: () -> ComponentBuilder.fromString('<box width="120" height="60" style="background-color:#8080c0;border:2px solid #000000;border-top-left-radius:20px;border-bottom-right-radius:20px" />')},
			{name: "style: opacity", make: () -> ComponentBuilder.fromString('<hbox><box width="60" height="60" style="background-color:#000000;opacity:0.3" /><box width="60" height="60" style="background-color:#000000;background-opacity:0.3;border:2px solid #000000;border-opacity:0.5" /></hbox>')},
			{name: "style: drop-shadow", make: () -> ComponentBuilder.fromString('<box width="100" height="60" style="background-color:#ffffff;filter:drop-shadow(4, 45, #000000, 0.5, 6, 1, 1, 3, false)" />')},
			{name: "style: inner shadow", make: () -> ComponentBuilder.fromString('<box width="100" height="60" style="background-color:#ffffff;filter:drop-shadow(2, 45, #000000, 0.5, 4, 1, 1, 3, true)" />')},
			{name: "style: blur + grayscale", make: () -> ComponentBuilder.fromString('<hbox><label text="Blur" style="font-size:20px;color:#ff0000;filter:blur(2)" /><label text="Gray" style="font-size:20px;color:#ff0000;filter:grayscale(100)" /></hbox>')},
			{name: "style: fonts", make: () -> ComponentBuilder.fromString('<vbox><label text="Bold" style="font-bold:true" /><label text="Italic" style="font-italic:true" /><label text="Underline" style="font-underline:true" /><label text="Strike" style="text-decoration:line-through" /><label text="Big 20" style="font-size:20px" /></vbox>')},
			{name: "style: font-name", make: () -> ComponentBuilder.fromString('<vbox><label text="Courier New" style="font-name:Courier New" /><label text="Georgia" style="font-name:Georgia" /><label text="monospace" style="font-name:monospace" /></vbox>')},
			{name: "style: text-align", make: () -> ComponentBuilder.fromString('<vbox width="150" style="background-color:#dddddd"><label width="100%" text="left" style="text-align:left" /><label width="100%" text="center" style="text-align:center" /><label width="100%" text="right" style="text-align:right" /></vbox>')},
			{name: "style: border-style", make: () -> ComponentBuilder.fromString('<hbox><box width="60" height="60" style="border:2px dashed #000000" /><box width="60" height="60" style="border:2px dotted #000000" /></hbox>')},
			{name: "style: bg image modes", make: () -> ComponentBuilder.fromString('<hbox><box width="60" height="60" style="background-image:haxeui-core/styles/default/haxeui_tiny.png;background-image-repeat:repeat;border:1px solid #000000" /><box width="60" height="60" style="background-image:haxeui-core/styles/default/haxeui_tiny.png;background-image-repeat:stretch;border:1px solid #000000" /></hbox>')},
			{name: "style: image scale-mode", make: () -> ComponentBuilder.fromString('<hbox><image width="60" height="40" resource="haxeui-core/styles/default/haxeui_tiny.png" scaleMode="fitinside" style="border:1px solid #000000" /><image width="60" height="40" resource="haxeui-core/styles/default/haxeui_tiny.png" scaleMode="fill" style="border:1px solid #000000" /></hbox>')},
			{name: "style: clip", make: () -> ComponentBuilder.fromString('<box width="80" height="30" style="clip:true;background-color:#dddddd"><label text="Clipped label that is too long" /></box>')},
			{name: "style: animation", make: () -> ComponentBuilder.fromString('<box width="60" height="60" style="background-color:#ff0000;animation:gallerypulse 1s linear 0s infinite" />')},
			{name: "style: padding/spacing", make: () -> ComponentBuilder.fromString('<hbox style="padding:10px;spacing:15px;background-color:#dddddd"><box width="20" height="20" style="background-color:#ff0000" /><box width="20" height="20" style="background-color:#00ff00" /></hbox>')},
			{name: "style: border sides", make: () -> ComponentBuilder.fromString('<box width="120" height="60" style="background-color:#ffffff;border-top-size:4;border-top-color:#ff0000;border-bottom-size:4;border-bottom-color:#0000ff;border-left-size:1;border-left-color:#000000;border-radius:10px" />')},
			{name: "style: generic fonts", make: () -> ComponentBuilder.fromString('<vbox><label text="serif" style="font-name:serif" /><label text="sans-serif" style="font-name:sans-serif" /><label text="Consolas" style="font-name:Consolas" /></vbox>')},
			{name: "textarea wrap=true xml", make: () -> ComponentBuilder.fromString('<textarea width="150" height="90" wrap="true" text="A textarea with enough words in it to wrap across several lines, and then some more." />')},
			{name: "textarea wrap=true code", make: () -> {
				var t = new haxe.ui.components.TextArea();
				t.width = 150;
				t.height = 90;
				t.text = "A textarea with enough words in it to wrap across several lines, and then some more.";
				t.wrap = true;
				return t;
			}},
			{name: "sample: html text", make: () -> {
				var l = new Label();
				l.htmlText = '<b>Bold</b>, <i>italic</i>, <u>under</u>, <font color="#CC0000">red</font><br><s>struck</s> &amp; plain';
				return l;
			}},
			{name: "style: rotation", make: () -> ComponentBuilder.fromString('<box width="80" height="20" style="background-color:#3366cc;rotation:30" />')},
			{name: "style: clip-path", make: () -> ComponentBuilder.fromString('<box width="80" height="60" style="background-color:#3366cc;clip-path:inset(10px 20px 10px 20px)" />')},
			{name: "sample: svg image", make: () -> {
				var image = new haxe.ui.components.Image();
				image.resource = '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><circle cx="20" cy="20" r="18" fill="#3366cc"/><rect x="12" y="12" width="16" height="16" fill="#ffcc00"/></svg>';
				image.width = 60;
				image.height = 60;
				return image;
			}},
			{name: "style: tooltip", make: () -> ComponentBuilder.fromString('<button text="Has tooltip" tooltip="I am a tooltip" />')},
		];
	}

	static function pageCount(list:Array<Entry>):Int {
		return Std.int((list.length + PER_PAGE - 1) / PER_PAGE);
	}

	/** One page of cells; `made` gets each (entry, component or error) as it is built. **/
	static function buildPage(list:Array<Entry>, page:Int, dark:Bool, made:Entry->Component->String->Void):VBox {
		var root = new VBox();
		root.percentWidth = 100;
		root.percentHeight = 100;
		root.styleString = "padding: 6px; background-color: " + (dark ? "#202326" : "#f4f4f4") + ";";
		var grid = new Grid();
		grid.columns = 8;
		root.addComponent(grid);
		var start = page * PER_PAGE;
		var end = Std.int(Math.min(start + PER_PAGE, list.length));
		for (i in start...end) {
			var e = list[i];
			var cell = new VBox();
			cell.width = 170;
			cell.height = 130;
			cell.styleString = "border: 1px solid #a0a0a0; padding: 3px; spacing: 2px;";
			var caption = new Label();
			caption.text = e.name.indexOf("haxe.ui.") == 0 ? e.name.substr(8) : e.name;
			caption.styleString = "font-size: 10px; color: #808080;";
			cell.addComponent(caption);
			var c:Component = null;
			var error:String = null;
			try c = e.make() catch (x:Dynamic) error = firstLine(x);
			if (c != null) {
				cell.addComponent(c);
			} else {
				var l = new Label();
				l.text = "CREATE FAILED";
				l.styleString = "color: #ff0000;";
				cell.addComponent(l);
			}
			grid.addComponent(cell);
			if (made != null) made(e, c, error);
		}
		return root;
	}

	#if haxeui_cs
	static function runCs(dark:Bool) {
		if (dark) Toolkit.theme = "dark";
		sys.FileSystem.createDirectory("tools/gallery/out");
		var suffix = dark ? "-dark" : "";
		var list = entries();
		var results:Array<String> = [];
		for (page in 0...pageCount(list)) {
			var built:Array<{e:Entry, c:Component}> = [];
			var root = buildPage(list, page, dark, function(e, c, error) {
				if (c == null) results.push('${e.name}\tCREATE FAILED\t$error');
				else built.push({e: e, c: c});
			});
			Screen.instance.addComponent(root);
			try {
				TestDriver.pump(6);
			} catch (x:Dynamic) {
				results.push('(page $page LAYOUT FAILED: ${firstLine(x)})');
				ValidationManager.instance.dispose();
			}
			TestDriver.capture('tools/gallery/out/page${page}$suffix.png');
			for (b in built) {
				if (b.e.name != "style: tooltip") continue;
				var p = TestDriver.centerOf(b.c);
				TestDriver.mouseMove(p.x, p.y);
				var t0 = haxe.Timer.stamp();
				while (haxe.Timer.stamp() - t0 < 2.0) TestDriver.pump();
				results.push('(tooltip hover: ${Screen.instance.rootComponents.length - 1} extra roots)');
				TestDriver.capture('tools/gallery/out/tooltip$suffix.png');
				TestDriver.mouseMove(1, 1);
				TestDriver.pump(2);
			}
			for (b in built) {
				var size = '${Std.int(b.c.width)}x${Std.int(b.c.height)}';
				var click = "ok";
				try {
					TestDriver.clickComponent(b.c);
					TestDriver.pump(2);
				} catch (x:Dynamic) {
					click = "CLICK FAILED " + firstLine(x);
					ValidationManager.instance.dispose();
				}
				var popups = Screen.instance.rootComponents.length - 1;
				for (r in Screen.instance.rootComponents.copy()) {
					if (r != root) try Screen.instance.removeComponent(r) catch (_:Dynamic) {}
				}
				results.push('${b.e.name}\tok\t$size\tclick=$click' + (popups > 0 ? '\tpopups=$popups' : ''));
			}
			Screen.instance.removeComponent(root);
			try TestDriver.pump() catch (_:Dynamic) ValidationManager.instance.dispose();
		}
		sys.io.File.saveContent('tools/gallery/out/results$suffix.txt', results.join("\n") + "\n");
		Sys.println('gallery: ${list.length} entries, ${pageCount(list)} pages');
		Sys.exit(0);
	}
	#end

	static function firstLine(e:Dynamic):String {
		var s = Std.string(e);
		var nl = s.indexOf("\n");
		return nl == -1 ? s : s.substr(0, nl);
	}
}
