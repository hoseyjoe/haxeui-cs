#!/bin/sh
# haxeui-cs is Haxe all through: no native/ folder, no inline C#, and no .cs of its own but the Android
# activity, which the Android build's tools need as C#. From the repo root: `sh tests/check-no-native.sh`.
failed=0

if [ -e native ]; then
	echo "native/ exists"
	failed=1
fi

inline=$(grep -r -n -w -E 'cs\.Syntax|untyped|__cs__' haxe)
if [ -n "$inline" ]; then
	echo "inline C# under haxe/:"
	printf '%s\n' "$inline"
	failed=1
fi

# tests/clipboard-app's helper reads the real Windows clipboard, to check the backend against it.
sources=$(git ls-files '*.cs' | grep -v -x -e templates/android/MainActivity.cs -e tests/clipboard-app/Win32Clipboard.cs)
if [ -n "$sources" ]; then
	echo ".cs files in the library:"
	printf '%s\n' "$sources"
	failed=1
fi

if [ $failed -ne 0 ]; then
	exit 1
fi
echo "no native ok"
