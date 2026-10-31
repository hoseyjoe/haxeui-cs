#!/bin/sh
# An hxc app needs nothing but hxc and dotnet: built with no project of its own into a folder with a
# space in its name, it runs from anywhere, and a failed fetch of Avalonia says so. From the repo
# root: `HXC=<hxc binary> sh tests/il-app/check.sh`.
: "${HXC:?set HXC to an hxc binary}"
export HAXE_STD_PATH="${HAXE_STD_PATH:-C:/HaxeToolkit/haxe/std}"
export MSYS_NO_PATHCONV=1
out="tests/il-app/bin with space"
failed=0

# expect <what> <text the output must hold> <output>
expect() {
	if printf '%s\n' "$3" | grep -q -F "$2"; then
		echo "ok: $1"
	else
		echo "FAILED: $1: no \"$2\" in:"
		printf '%s\n' "$3" | tail -20
		failed=1
	fi
}

rm -rf "$out"
built=$("$HXC" tests/il-app/build.hxml 2>&1)
if [ $? -ne 0 ] || [ ! -f "$out/App.dll" ]; then
	echo "FAILED: the build:"
	printf '%s\n' "$built" | tail -20
	exit 1
fi
full=$(cd "$out" && pwd -W 2>/dev/null || pwd)

expect "dotnet, in a folder with a space" ready "$(dotnet "$out/App.dll" 2>&1)"
elsewhere=$(cd /c 2>/dev/null || cd /; dotnet "$full/App.dll" 2>&1)
expect "from elsewhere" ready "$elsewhere"
expect "from elsewhere, an embedded resource" "resource loaded" "$elsewhere"
if [ -f "$out/App.exe" ]; then
	expect "App.exe" ready "$("$out/App.exe" 2>&1)"
fi

# In WSL, with the .NET 10 and Avalonia native libraries the README's Linux section sets up.
if command -v wsl.exe > /dev/null 2>&1; then
	path=$(wsl.exe wslpath -a "$full" | tr -d '\000\r')
	expect "on WSL" ready "$(wsl.exe -e sh -c "LD_LIBRARY_PATH=\$HOME/avalonia-libs \$HOME/.dotnet10/dotnet '$path/App.dll'" 2>&1)"
fi

rm -rf .cache/il
empty=$(mktemp -d)
offline=$(NUGET_PACKAGES="$empty/packages" NUGET_HTTP_CACHE_PATH="$empty/http" RestoreSources=http://127.0.0.1:9/ "$HXC" tests/il-app/build.hxml 2>&1)
status=$?
rm -rf "$empty"
if [ $status -eq 0 ]; then
	echo "FAILED: the build with nothing to fetch from succeeded"
	failed=1
fi
expect "no way to fetch, names haxeui-cs" "haxeui-cs" "$offline"
expect "no way to fetch, says what" "fetching Avalonia" "$offline"

if [ $failed -ne 0 ]; then
	exit 1
fi
echo "il-app ok"
