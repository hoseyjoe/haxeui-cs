#!/bin/sh
# The suite under hxc's -D dotnet, against the prebuilt C#. From the repo root:
# `HXC=<hxc binary> sh tests/run-il.sh`. Arguments go to hxc, so `-D test=<Case>` runs one case.
set -e
: "${HXC:?set HXC to an hxc binary}"
export HAXE_STD_PATH="${HAXE_STD_PATH:-C:/HaxeToolkit/haxe/std}"
native=tests/il-native/bin/Debug/net10.0
dotnet build tests/il-native/HaxeUICs.csproj -nologo -v q
"$HXC" tests/headless-il.hxml "$@"
cp "$native"/*.dll tests/bin-il/
rid=$(dotnet --info | sed -n 's/^ *RID: *//p' | head -1 | tr -d '\r')
if [ -d "$native/runtimes/$rid/native" ]; then
	cp "$native/runtimes/$rid/native/"* tests/bin-il/
fi
dotnet tests/bin-il/TestMain.dll
