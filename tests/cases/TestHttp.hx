package cases;

import cs.system.io.Directory;
import cs.system.io.File;
import cs.system.io.Path;
import cs.system.text.Encoding;
import haxe.ui.backend.cs.native.Native;
import haxe.ui.backend.cs.net.Http;
import utest.Assert;

/** .NET's HTTP client through the hand-written externs, as an app posts with it. **/
class TestHttp extends utest.Test {
	var dir:String;
	var port:Int;

	function setup() {
		dir = Path.Combine(Path.GetTempPath(), "haxeui-cs-http-" + Std.random(1000000));
		Directory.CreateDirectory(dir);
		File.WriteAllText(Path.Combine(dir, "note.txt"), "héllo");
		port = HeadlessDriver.StartHttpServer(dir, 0);
	}

	function teardown() {
		HeadlessDriver.StopHttpServer();
		Directory.Delete(dir, true);
	}

	function post(name:String):HttpResponseMessage {
		return new HttpClient(new HttpClientHandler()).Send(new HttpRequestMessage(HttpMethod.Post, 'http://127.0.0.1:$port/$name'));
	}

	function testASuccessHasItsStatusAndBody() {
		var response = post("note.txt");
		var status:Int = cast response.StatusCode;
		Assert.equals(200, status);
		Assert.equals("héllo", response.Content.ReadAsStringAsync().Result);
		response.Dispose();
	}

	function testAFailureIsAStatusNotAThrow() {
		var response = post("missing.txt");
		var status:Int = cast response.StatusCode;
		Assert.equals(404, status);
		response.Dispose();
	}

	function testNothingListeningThrows() {
		HeadlessDriver.StopHttpServer();
		Assert.raises(() -> post("note.txt"));
	}

	function testContentAndHeadersGoOnARequest() {
		var request = new HttpRequestMessage(HttpMethod.Post, 'http://127.0.0.1:$port/note.txt');
		request.Content = new StringContent("héllo 😀", Encoding.UTF8, "application/json");
		Assert.equals("héllo 😀", request.Content.ReadAsStringAsync().Result);
		Assert.isTrue(request.Headers.TryAddWithoutValidation("X-Probe", "kept"));
	}

	function testACertificateCheckCanBeTurnedOff() {
		var handler = new HttpClientHandler();
		handler.ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator;
		Assert.notNull(handler.ServerCertificateCustomValidationCallback);
	}
}
