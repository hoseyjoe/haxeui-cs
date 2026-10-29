package cases;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.zip.Compress;
import haxe.zip.Uncompress;
import utest.Assert;

/** haxe.zip.Compress, which Haxe 4.3's C# std leaves unimplemented (NativeCompress). **/
class TestCompress extends utest.Test {
	static function sample():Bytes {
		var b = new BytesBuffer();
		for (i in 0...2000)
			b.addString('line $i of a fairly repetitive text, compressible\n');
		return b.getBytes();
	}

	function testRunIsAZlibStream() {
		var data = sample();
		var z = Compress.run(data, 6);
		Assert.isTrue(z.length < data.length / 4, 'compressed to ${z.length} of ${data.length}');
		Assert.equals(0x78, z.get(0), "zlib header: deflate, 32K window");
		Assert.equals(0, ((z.get(0) << 8) | z.get(1)) % 31, "zlib header check bits");
		// the trailer is the input's Adler-32, big-endian, as zlib writes it
		var adler = (z.get(z.length - 4) << 24) | (z.get(z.length - 3) << 16) | (z.get(z.length - 2) << 8) | z.get(z.length - 1);
		Assert.equals(haxe.crypto.Adler32.make(data), adler);
		Assert.equals(data.toHex(), Uncompress.run(z).toHex());
	}

	function testLevels() {
		var data = sample();
		var stored = Compress.run(data, 0);
		var best = Compress.run(data, 9);
		Assert.isTrue(stored.length > data.length, 'level 0 stores: ${stored.length}');
		Assert.isTrue(best.length <= Compress.run(data, 1).length, "level 9 no bigger than level 1");
		for (level in [0, 1, 6, 9])
			Assert.equals(data.toHex(), Uncompress.run(Compress.run(data, level)).toHex(), 'level $level');
	}

	function testEmpty() {
		var z = Compress.run(Bytes.alloc(0), 6);
		Assert.equals(0, Uncompress.run(z).length);
	}

	function testExecuteIntoSmallBuffer() {
		var data = sample();
		var c = new Compress(6);
		c.setFlushMode(FINISH);
		var out = new BytesBuffer();
		var buf = Bytes.alloc(100);
		var pos = 0;
		var calls = 0;
		while (true) {
			var r = c.execute(data, pos, buf, 0);
			pos += r.read;
			out.addBytes(buf, 0, r.write);
			if (r.done) break;
			if (++calls > 10000) break;
		}
		c.close();
		var z = out.getBytes();
		Assert.isTrue(calls > 1, "the output came over several calls");
		Assert.equals(data.length, pos, "all of the input read");
		Assert.equals(data.toHex(), Uncompress.run(z).toHex());
		Assert.equals(Compress.run(data, 6).toHex(), z.toHex(), "the same stream as run");
	}
}
