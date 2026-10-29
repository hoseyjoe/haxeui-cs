#!/usr/bin/env bash
# The Android check on a real device: builds, installs and drives tests/android-app on the device
# ANDROID_SERIAL names, reading what the app reports from logcat. `bash tests/android-app/check-device.sh`
# from the repo root. It uninstalls the app first (a clean files dir), and puts the device's
# rotation settings back when it ends.
set -u
: "${ANDROID_SERIAL:?set ANDROID_SERIAL to the device to test on (adb devices lists them)}"
export ANDROID_SERIAL MSYS_NO_PATHCONV=1
id=org.haxeui.cs.androidapp
bin=tests/android-app/bin
mkdir -p "$bin"

lines() { adb logcat -d | grep -a "android-app: " | sed 's/.*android-app: /android-app: /' | tr -d '\r'; }
count() { lines | grep -cE "$1"; }
restore() {
  [ -n "${accel:-}" ] && adb shell settings put system accelerometer_rotation "$accel"
  [ -n "${userrot:-}" ] && adb shell settings put system user_rotation "$userrot"
}
fail() { echo "check-device: FAIL: $1"; lines | tail -20; restore; exit 1; }
pass() { echo "check-device: ok: $1"; }
wait_for() {
  for _ in $(seq 1 60); do lines | grep -qE "$1" && return 0; sleep 0.5; done
  fail "timed out waiting for /$1/"
}
launch() { adb shell monkey -p "$id" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1; }

adb uninstall "$id" > /dev/null 2>&1
adb logcat -c
haxe tests/android-app/build.hxml -D haxeui_cs_run > "$bin/device-build.log" 2>&1 || { tail -20 "$bin/device-build.log"; fail "build or install"; }

# 1. main runs in the files dir, then HaxeUI is ready with a real screen size at scale 1
wait_for "^android-app: main ran 1 cwd /data/(data|user/0)/$id/files$"
wait_for "^android-app: ready [1-9][0-9]{2,}x[1-9][0-9]{2,} scale 1$"
pass "main ran once in the files dir; ready"

# 2. a tap is a click
wait_for "^android-app: button [0-9]+ [0-9]+$"
read -r x y < <(lines | grep -E "^android-app: button " | tail -1 | awk '{print $3, $4}')
adb shell input tap "$x" "$y"
wait_for "^android-app: clicked$"
pass "tap at $x,$y clicked the button"

# 3. rotating resizes and reflows; it never restarts the app
accel=$(adb shell settings get system accelerometer_rotation | tr -d '\r')
userrot=$(adb shell settings get system user_rotation | tr -d '\r')
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
wait_for "^android-app: resized ([0-9]+)x([0-9]+)$"
landscape=$(lines | grep -E "^android-app: resized " | tail -1 | awk '{split($3, s, "x"); print (s[1] > s[2]) ? "yes" : "no"}')
[ "$landscape" = yes ] || fail "after rotating, the last size is not landscape"
adb shell settings put system user_rotation 0
sleep 2
[ "$(count '^android-app: ready ')" = 1 ] || fail "ready ran again after rotating"
[ "$(count '^android-app: main ran ')" = 1 ] || fail "main ran again after rotating"
restore
pass "rotation resized to landscape and back without a restart"

# 4. back goes to the background (paused); launching again finds the same process, main not rerun
pid=$(adb shell pidof "$id" | tr -d '\r')
adb shell input keyevent KEYCODE_BACK
wait_for "^android-app: paused$"
launch
sleep 3
[ "$(adb shell pidof "$id" | tr -d '\r')" = "$pid" ] || fail "back ended the process"
[ "$(count '^android-app: main ran ')" = 1 ] || fail "main ran again after back and relaunch"
pass "back paused the app; relaunch resumed process $pid without running main again"

# 5. killed in the background, launched again: main runs again, and finds what it wrote before
adb shell input keyevent KEYCODE_HOME
sleep 1
adb shell am kill "$id"
sleep 1
[ -z "$(adb shell pidof "$id" | tr -d '\r')" ] || fail "am kill left the process running"
launch
wait_for "^android-app: main ran 2 cwd /data/(data|user/0)/$id/files$"
pass "after a kill, main ran again and found its earlier run"

# 6. nothing crashed; a picture of the screen for a look
sleep 2
adb exec-out screencap -p > "$bin/screen.png"
adb logcat -d -b crash | grep -q "$id" && fail "a crash was logged for $id"
pass "no crash logged; screen in $bin/screen.png"
echo "check-device: OK"
