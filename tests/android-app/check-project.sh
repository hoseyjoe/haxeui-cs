#!/usr/bin/env bash
# The Android project the build writes, checked without a device or a dotnet build.
# `bash tests/android-app/check-project.sh` from the repo root.
set -u
bin=tests/android-app/bin
fail() { echo "check-project: FAIL: $1"; exit 1; }

haxe tests/android-app/build.hxml -D haxeui_cs_no_dotnet > "$bin.log" 2>&1 || { cat "$bin.log"; fail "the build failed"; }
csproj=$bin/Main.csproj
for want in '<TargetFramework>net10.0-android</TargetFramework>' \
            '<ApplicationId>org.haxeui.cs.androidapp</ApplicationId>' \
            '<ApplicationTitle>android-app</ApplicationTitle>' \
            'Include="Avalonia.Android"' \
            '<PublishTrimmed>false</PublishTrimmed>' \
            '<AndroidLinkMode>None</AndroidLinkMode>' \
            '<RuntimeIdentifier>android-arm64</RuntimeIdentifier>'; do
  grep -qF "$want" "$csproj" || fail "$csproj lacks $want"
done
grep -qF 'Avalonia.Desktop' "$csproj" && fail "$csproj still references Avalonia.Desktop"
grep -qF 'global::Main.main();' "$bin/android/MainActivity.cs" || fail "MainActivity.cs does not call global::Main.main()"
grep -qF 'Label = "android-app"' "$bin/android/MainActivity.cs" || fail "MainActivity.cs lacks the label"
grep -qF '[System.STAThread]' "$bin/src/Main.cs" && fail "the Android entry point was marked [STAThread]"

haxe tests/android-app/build.hxml -D haxeui_cs_no_dotnet -D haxeui_cs_android_abi=x86_64 > "$bin.log" 2>&1 || fail "the x86_64 build failed"
grep -qF '<RuntimeIdentifier>android-x64</RuntimeIdentifier>' "$csproj" || fail "x86_64 is not android-x64"

# Without an application id the build must stop and say so.
sed '/haxeui_cs_android_id/d' tests/android-app/build.hxml > "$bin-noid.hxml"
if haxe "$bin-noid.hxml" -D haxeui_cs_no_dotnet > "$bin.log" 2>&1; then fail "a build without an application id succeeded"; fi
grep -qF 'haxeui-cs: -D haxeui_cs_android needs -D haxeui_cs_android_id=<application id>' "$bin.log" || { cat "$bin.log"; fail "no clear error without an application id"; }
rm -f "$bin-noid.hxml" "$bin.log"
echo "check-project: OK"
