#!/usr/bin/env bash
# 켜 둔 에뮬레이터에 릴리스 산출물 4개(APK 2 + AAB 2)를 설치해 실행하고, 크래시 없이 살아 있는지 본다 (REQ-46).
# R8·매니페스트 문제는 단위 테스트로 안 잡히고 실행해 봐야만 드러난다.
# 사용: tools/smoke_test.sh <bundletool.jar> <dist 폴더> (폴더에 없는 파일은 건너뜀)
set -u
BUNDLETOOL=$1
DIST=$2
ADB=${ADB:-adb}
PKG=com.wani.card_expense
WAIT=${SMOKE_WAIT:-30} # 에뮬레이터는 ARM 번역이라 첫 실행이 느리다
WORK=$(mktemp -d)
fail=0

# 앱은 ARM 라이브러리만 있어서 x86_64 이미지의 ARM 번역이 있어야 돈다
ABIS=$("$ADB" shell getprop ro.product.cpu.abilist | tr -d '\r')
echo "에뮬레이터 ABI: $ABIS"
case "$ABIS" in
  *arm64-v8a*) ;;
  *) echo "::error::이 에뮬레이터는 arm64 앱을 실행할 수 없습니다 ($ABIS)"; exit 1 ;;
esac

# bundletool 이 APK 세트에 서명할 키. 없으면 시험용으로 만든다 (릴리스 키는 쓰지 않음)
if [ ! -f "$HOME/.android/debug.keystore" ]; then
  mkdir -p "$HOME/.android"
  keytool -genkeypair -keystore "$HOME/.android/debug.keystore" -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 3650
fi

launch() {
  "$ADB" logcat -c
  "$ADB" shell am start -W -n "$PKG/.MainActivity" >/dev/null
  sleep "$WAIT"
  local pid crash
  pid=$("$ADB" shell pidof "$PKG" | tr -d '\r')
  crash=$("$ADB" logcat -d -b crash | grep -E "FATAL EXCEPTION|Fatal signal" | grep -c "" || true)
  if [ -z "$pid" ] || [ "$crash" != 0 ]; then
    echo "::error::$1 실행 실패 (pid='$pid', 크래시 $crash건)"
    "$ADB" logcat -d -b crash | grep -E "FATAL|Process:|Caused by|Fatal signal" | head -20
    fail=1
  else
    echo "통과: $1 (pid $pid, ${WAIT}초 생존)"
  fi
  "$ADB" uninstall "$PKG" >/dev/null 2>&1
}

"$ADB" uninstall "$PKG" >/dev/null 2>&1
for f in app-release.apk app-full-release.apk; do
  [ -f "$DIST/$f" ] || continue
  if "$ADB" install -r "$DIST/$f" >/dev/null; then launch "$f"; else echo "::error::$f 설치 실패"; fail=1; fi
done
for f in app-store-public-release.aab app-store-full-release.aab; do
  [ -f "$DIST/$f" ] || continue
  # 스토어와 같은 분할 설치 (base + ABI + 언어 + 화면 밀도)
  if java -jar "$BUNDLETOOL" build-apks --bundle="$DIST/$f" --output="$WORK/$f.apks" --connected-device --adb="$(command -v "$ADB")" --overwrite >/dev/null &&
    java -jar "$BUNDLETOOL" install-apks --apks="$WORK/$f.apks" --adb="$(command -v "$ADB")" >/dev/null; then
    launch "$f"
  else
    echo "::error::$f 설치 실패"
    fail=1
  fi
done
rm -rf "$WORK"
exit $fail
