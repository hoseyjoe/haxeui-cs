#!/bin/sh
# The suite under hxc's -D dotnet. From the repo root: `HXC=<hxc binary> sh tests/run-il.sh`.
# Arguments go to hxc, so `-D test=<Case>` runs one case.
set -e
: "${HXC:?set HXC to an hxc binary}"
export HAXE_STD_PATH="${HAXE_STD_PATH:-C:/HaxeToolkit/haxe/std}"
"$HXC" tests/headless-il.hxml "$@"
dotnet tests/bin-il/TestMain.dll
