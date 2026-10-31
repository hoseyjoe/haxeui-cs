package haxe.ui.backend.cs.net;

import cs.system.Func_5;
import cs.system.IDisposable;
import cs.system.text.Encoding;
import haxe.ui.backend.cs.net.Net.Task_1;

/**
 * Externs for .NET's HTTP client, written by hand as hxc binds them. haxeui-cs itself doesn't use
 * them: they are for apps, as Haxe's C# target has no TLS sockets, so `sys.Http` can't do https there.
 */
@:native("System.Net.Http.HttpMethod")
extern class HttpMethod {
	@:overload function new(method:String);
	static var Post(default, never):HttpMethod;
}

@:native("System.Net.Http.HttpContent")
extern class HttpContent {
	@:overload function ReadAsStringAsync():Task_1<String>;
	@:overload function ReadAsByteArrayAsync():Task_1<cs.NativeArray<cs.types.UInt8>>;
}

@:native("System.Net.Http.StringContent")
extern class StringContent extends HttpContent {
	@:overload function new(content:String, encoding:Encoding, mediaType:String);
}

@:native("System.Net.Http.Headers.HttpHeaders")
extern class HttpHeaders {
	@:overload function TryAddWithoutValidation(name:String, value:String):Bool;
}

@:native("System.Net.Http.Headers.HttpRequestHeaders")
extern class HttpRequestHeaders extends HttpHeaders {}

@:native("System.Net.Http.HttpRequestMessage")
extern class HttpRequestMessage {
	@:overload function new(method:HttpMethod, requestUri:String);
	var Content:HttpContent;
	var Headers(default, never):HttpRequestHeaders;
}

/** Read it as a number with `var status:Int = cast response.StatusCode`. **/
@:native("System.Net.HttpStatusCode")
extern enum HttpStatusCode {}

@:native("System.Net.Http.HttpResponseMessage")
extern class HttpResponseMessage implements IDisposable {
	var StatusCode(default, never):HttpStatusCode;
	var Content(default, never):HttpContent;
	function Dispose():Void;
}

@:native("System.Security.Cryptography.X509Certificates.X509Certificate2")
extern class X509Certificate2 {}

@:native("System.Security.Cryptography.X509Certificates.X509Chain")
extern class X509Chain {}

@:native("System.Net.Security.SslPolicyErrors")
extern enum SslPolicyErrors {}

@:native("System.Net.Http.HttpMessageHandler")
extern class HttpMessageHandler {}

@:native("System.Net.Http.HttpClientHandler")
extern class HttpClientHandler extends HttpMessageHandler {
	function new();
	var ServerCertificateCustomValidationCallback:Func_5<HttpRequestMessage, X509Certificate2, X509Chain, SslPolicyErrors, Bool>;
	static var DangerousAcceptAnyServerCertificateValidator(default, never):Func_5<HttpRequestMessage, X509Certificate2, X509Chain, SslPolicyErrors, Bool>;
}

@:native("System.Net.Http.HttpClient")
extern class HttpClient {
	@:overload function new(handler:HttpMessageHandler);
	@:overload function Send(request:HttpRequestMessage):HttpResponseMessage;
}
