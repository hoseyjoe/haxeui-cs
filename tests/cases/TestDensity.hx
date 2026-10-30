package cases;

import haxe.ui.backend.cs.Density;
import haxe.ui.backend.cs.native.Native;
import utest.Assert;

/** The Toolkit scale that gives a design width whole device pixels per unit. **/
class TestDensity extends utest.Test {
	function testScaleIsTheWholeMultipleOverTheDensity() {
		var surface = Math.min(Host.ClientWidth, Host.ClientHeight) * Host.RenderScaling;
		var design = surface / 3;
		Assert.floatEquals(3 / Host.RenderScaling, Density.scaleFor(design));
	}

	function testRoundsToTheNearestWholeMultiple() {
		var surface = Math.min(Host.ClientWidth, Host.ClientHeight) * Host.RenderScaling;
		Assert.floatEquals(2 / Host.RenderScaling, Density.scaleFor(surface / 2.4));
		Assert.floatEquals(3 / Host.RenderScaling, Density.scaleFor(surface / 2.6));
	}

	function testASmallerScreenThanTheDesignIsOnePixelAUnit() {
		var surface = Math.min(Host.ClientWidth, Host.ClientHeight) * Host.RenderScaling;
		Assert.floatEquals(1 / Host.RenderScaling, Density.scaleFor(surface * 10));
	}
}
