#!/bin/sh
# The suite under hxc's --dotnet. From the repo root: `HXC=<hxc binary> sh tests/run-il.sh`.
# Arguments go to hxc, so `-D test=<Case>` runs one case. HXML picks the build: tests/headless-il.hxml
# (the default: what ships) or tests/headless-drive-il.hxml (with -D haxeui_cs_drive, which adds TestAppDriver):
#   HXML=tests/headless-drive-il.hxml HXC=<hxc binary> sh tests/run-il.sh -D test=TestAppDriver
set -e
: "${HXC:?set HXC to an hxc binary}"
export HAXE_STD_PATH="${HAXE_STD_PATH:-C:/HaxeToolkit/haxe/std}"
"$HXC" "${HXML:-tests/headless-il.hxml}" "$@"
dotnet tests/bin-il/TestMain.dll
