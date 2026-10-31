#!/bin/sh
# Compiles the ported C# with hxc alone and checks it. Needs a Haxe 4.3.7 suite build in tests/bin, for
# its libraries. From the repo root: `HXC=<hxc binary> sh tests/native-il/run.sh`.
set -e
: "${HXC:?set HXC to an hxc binary}"
export HAXE_STD_PATH="${HAXE_STD_PATH:-C:/HaxeToolkit/haxe/std}"
libs=tests/bin/bin/Debug/net10.0
"$HXC" tests/native-il/build.hxml
cp "$libs"/*.dll tests/native-il/bin/
rm -f tests/native-il/bin/HaxeUICs.dll tests/native-il/bin/TestMain.dll
rid=$(dotnet --info | sed -n 's/^ *RID: *//p' | head -1 | tr -d '\r')
if [ -d "$libs/runtimes/$rid/native" ]; then
	cp "$libs/runtimes/$rid/native/"* tests/native-il/bin/
fi
dotnet tests/native-il/bin/bin.dll
