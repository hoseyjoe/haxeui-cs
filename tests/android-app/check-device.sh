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
# Where the fixture says a control is, in device pixels: "x y".
at() { lines | grep -E "^android-app: at $1 " | tail -1 | awk '{print $4, $5}'; }
# Taps the first view on screen (another app's, a system picker) whose text or content
# description is $1; false if none.
tap_text() {
  adb shell uiautomator dump /sdcard/check-ui.xml > /dev/null 2>&1
  local b
  b=$(adb shell cat /sdcard/check-ui.xml | tr '>' '\n' | grep -E "(text|content-desc)=\"$1\"" | head -1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '[0-9]+')
  [ -n "$b" ] || return 1
  set -- $b
  adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}

adb uninstall "$id" > /dev/null 2>&1
adb logcat -c
haxe tests/android-app/build.hxml -D haxeui_cs_run > "$bin/device-build.log" 2>&1 || { tail -20 "$bin/device-build.log"; fail "build or install"; }

# 1. main runs in the files dir, then HaxeUI is ready with a real screen size at scale 1
wait_for "^android-app: main ran 1 cwd /data/(data|user/0)/$id/files$"
wait_for "^android-app: ready [1-9][0-9]{2,}x[1-9][0-9]{2,} scale 1$"
pass "main ran once in the files dir; ready"

# 2. a tap is a click
wait_for "^android-app: at field [0-9]+ [0-9]+$"
read -r x y < <(at tap)
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

# 6. full screen: the status bar is hidden (this API 36 phone lists it as an InsetsSource line)
wait_for "^android-app: at field .*" # the relaunched run has laid out
for _ in $(seq 1 20); do
  adb shell dumpsys window | grep -qE "InsetsSource id=[^ ]+ type=statusBars .*visible=false" && break
  sleep 0.5
done
adb shell dumpsys window | grep -qE "InsetsSource id=[^ ]+ type=statusBars .*visible=false" || fail "the status bar is showing"
pass "immersive: the status bar is hidden"

# 7. back with a listener armed: the listener takes it, the app stays in front
sleep 1
read -r x y < <(at trap)
adb shell input tap "$x" "$y"
wait_for "^android-app: back armed$"
paused=$(count '^android-app: paused$')
adb shell input keyevent KEYCODE_BACK
wait_for "^android-app: back trapped$"
sleep 1
[ "$(count '^android-app: paused$')" = "$paused" ] || fail "a trapped back still left the app"
pass "back went to the armed listener and the app stayed"

# 8. a long press shows the tooltip, and letting go is not a click
read -r x y < <(at hold)
adb shell input swipe "$x" "$y" "$x" "$y" 2000 &
wait_for "^android-app: tooltip shown$"
wait
sleep 1
[ "$(count '^android-app: tip clicked$')" = 0 ] || fail "letting go of a long press clicked the button"
pass "a long press showed the tooltip; letting go did not click"

# 9. the system picker: the chosen file is copied into files/picked, the same file twice is one copy
adb push tests/assets/red4x4.png /sdcard/Download/pick.png > /dev/null
bytes=$(wc -c < tests/assets/red4x4.png | tr -d ' ')
pick() {
  read -r x y < <(at open)
  adb shell input tap "$x" "$y"
  for _ in $(seq 1 20); do
    sleep 1
    tap_text 'pick\.png' && return 0
    # It opens on Recent files, where a file adb pushed is not listed: Downloads, from the drawer.
    tap_text Downloads || tap_text 'Show roots'
  done
  fail "pick.png never showed in the picker"
}
pick
wait_for "^android-app: opened /data/(data|user/0)/$id/files/picked/pick.png $bytes$"
pick
for _ in $(seq 1 20); do [ "$(count "^android-app: opened .*/files/picked/pick.png $bytes$")" = 2 ] && break; sleep 0.5; done
[ "$(count "^android-app: opened .*/files/picked/pick.png $bytes$")" = 2 ] || fail "picking the same file again did not give the same copy"
[ "$(count '^android-app: opened .*pick \(')" = 0 ] || fail "picking the same file again made a second copy"
adb shell rm /sdcard/Download/pick.png /sdcard/check-ui.xml
pass "picked files land in files/picked; the same file again is the same copy"

# 10. tapping a text field brings up the keyboard
read -r x y < <(at field)
adb shell input tap "$x" "$y"
for _ in $(seq 1 20); do adb shell dumpsys input_method | grep -q "mInputShown=true" && break; sleep 0.5; done
adb shell dumpsys input_method | grep -q "mInputShown=true" || fail "no keyboard after tapping the text field"
pass "a text field brings up the keyboard"

# 11. nothing crashed; a picture of the screen for a look
sleep 2
adb exec-out screencap -p > "$bin/screen.png"
adb logcat -d -b crash | grep -q "$id" && fail "a crash was logged for $id"
pass "no crash logged; screen in $bin/screen.png"
echo "check-device: OK"
