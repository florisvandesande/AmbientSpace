#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/deploy_macos.example.sh"
PROJECT_PATH="$ROOT_DIR/ios-app/AmbientSpace.xcodeproj"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ambientspace-deploy-contract.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$FAKE_BIN"

UNIVERSAL_FIXTURE="$TEST_ROOT/universal-fixture"
X86_64_FIXTURE="$TEST_ROOT/x86_64-fixture"
cp /usr/bin/true "$UNIVERSAL_FIXTURE"
lipo -thin x86_64 "$UNIVERSAL_FIXTURE" -output "$X86_64_FIXTURE"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

assert_setting() {
    local target="$1"
    local setting="$2"
    local expected="$3"
    local actual
    actual="$(xcodebuild -project "$PROJECT_PATH" -target "$target" -sdk macosx -showBuildSettings 2>/dev/null | awk -v key="$setting" '$1 == key && $2 == "=" { print $3; exit }')"
    [[ "$actual" == "$expected" ]] || {
        printf 'Expected %s %s, got %s.\n' "$target" "$setting" "${actual:-<missing>}" >&2
        return 1
    }
}

assert_setting AmbientSpace MACOSX_DEPLOYMENT_TARGET 13.0
assert_setting AmbientSpaceWidgets MACOSX_DEPLOYMENT_TARGET 14.0

cat > "$FAKE_BIN/xcodebuild" <<'FAKE_XCODEBUILD'
#!/usr/bin/env bash

set -euo pipefail

derived_data_path=""
configuration="Debug"
bundle_id="com.example.AmbientSpace"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -derivedDataPath)
            derived_data_path="$2"
            shift 2
            ;;
        -configuration)
            configuration="$2"
            shift 2
            ;;
        AMBIENTSPACE_BUNDLE_ID=*)
            bundle_id="${1#AMBIENTSPACE_BUNDLE_ID=}"
            shift
            ;;
        *)
            printf '%s\n' "$1" >> "${FAKE_XCODEBUILD_LOG:?}"
            shift
            ;;
    esac
done

printf 'ARCHS=%s\n' "${FAKE_ARCHS:?}" >> "${FAKE_XCODEBUILD_LOG:?}"
printf 'ONLY_ACTIVE_ARCH=%s\n' "${FAKE_ONLY_ACTIVE_ARCH:?}" >> "${FAKE_XCODEBUILD_LOG:?}"

app_path="$derived_data_path/Build/Products/${configuration}-maccatalyst/AmbientSpace.app"
widget_path="$app_path/Contents/PlugIns/AmbientSpaceWidgets.appex"
mkdir -p "$app_path/Contents/MacOS" "$widget_path/Contents/MacOS"

cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleExecutable</key>
    <string>AmbientSpace</string>
    <key>LSMinimumSystemVersion</key>
    <string>${FAKE_APP_MINIMUM:?}</string>
</dict>
</plist>
PLIST

cat > "$widget_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}.Widgets</string>
    <key>CFBundleExecutable</key>
    <string>AmbientSpaceWidgets</string>
    <key>LSMinimumSystemVersion</key>
    <string>${FAKE_WIDGET_MINIMUM:?}</string>
</dict>
</plist>
PLIST

cp "${FAKE_EXECUTABLE_FIXTURE:?}" "$app_path/Contents/MacOS/AmbientSpace"
cp "${FAKE_EXECUTABLE_FIXTURE:?}" "$widget_path/Contents/MacOS/AmbientSpaceWidgets"
FAKE_XCODEBUILD
chmod +x "$FAKE_BIN/xcodebuild"

cat > "$FAKE_BIN/open" <<'FAKE_OPEN'
#!/usr/bin/env bash

set -euo pipefail

: > "${FAKE_RUNNING_FILE:?}"
FAKE_OPEN
chmod +x "$FAKE_BIN/open"

cat > "$FAKE_BIN/pgrep" <<'FAKE_PGREP'
#!/usr/bin/env bash

set -euo pipefail

[[ -e "${FAKE_RUNNING_FILE:?}" ]]
FAKE_PGREP
chmod +x "$FAKE_BIN/pgrep"

cat > "$FAKE_BIN/osascript" <<'FAKE_OSASCRIPT'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >> "${FAKE_OSASCRIPT_LOG:?}"
if [[ "$*" == *'to quit'* ]]; then
    rm -f "${FAKE_RUNNING_FILE:?}"
fi
FAKE_OSASCRIPT
chmod +x "$FAKE_BIN/osascript"

run_deploy() {
    local expected_status="$1"
    local output_file="$2"
    local mode="$3"
    shift 3

    local -a deploy_arguments=()
    if [[ "$mode" == "build-only" ]]; then
        deploy_arguments+=(--build-only)
    fi

    set +e
    PATH="$FAKE_BIN:$PATH" \
        FAKE_ARCHS="${FAKE_ARCHS_VALUE:-x86_64 arm64}" \
        FAKE_ONLY_ACTIVE_ARCH="${FAKE_ONLY_ACTIVE_ARCH_VALUE:-NO}" \
        FAKE_APP_MINIMUM="${FAKE_APP_MINIMUM_VALUE:-13.0}" \
        FAKE_WIDGET_MINIMUM="${FAKE_WIDGET_MINIMUM_VALUE:-14.0}" \
        FAKE_EXECUTABLE_FIXTURE="${FAKE_EXECUTABLE_FIXTURE_VALUE:-$UNIVERSAL_FIXTURE}" \
        FAKE_XCODEBUILD_LOG="$TEST_ROOT/xcodebuild.log" \
        BUNDLE_ID="com.example.ambientspace" \
        DERIVED_DATA_PATH="$TEST_ROOT/build" \
        INSTALL_PATH="$TEST_ROOT/install/AmbientSpace.app" \
        FAKE_RUNNING_FILE="$TEST_ROOT/running" \
        FAKE_OSASCRIPT_LOG="$TEST_ROOT/osascript.log" \
        MAC_ARCH="universal" \
        CODE_SIGNING_ALLOWED=NO \
        bash "$SCRIPT_PATH" "${deploy_arguments[@]}" > "$output_file" 2>&1
    local actual_status=$?
    set -e

    if [[ "$actual_status" -ne "$expected_status" ]]; then
        printf 'Expected exit status %s, got %s. Output:\n' "$expected_status" "$actual_status" >&2
        cat "$output_file" >&2
        return 1
    fi
}

: > "$TEST_ROOT/xcodebuild.log"
run_deploy 0 "$TEST_ROOT/success.log" build-only
grep -q '^ARCHS=x86_64 arm64$' "$TEST_ROOT/xcodebuild.log"
grep -q '^ONLY_ACTIVE_ARCH=NO$' "$TEST_ROOT/xcodebuild.log"

FAKE_EXECUTABLE_FIXTURE_VALUE="$X86_64_FIXTURE" run_deploy 1 "$TEST_ROOT/missing-arm64.log" build-only
FAKE_APP_MINIMUM_VALUE="14.0" run_deploy 1 "$TEST_ROOT/high-app-minimum.log" build-only
FAKE_WIDGET_MINIMUM_VALUE="13.0" run_deploy 1 "$TEST_ROOT/low-widget-minimum.log" build-only

run_deploy 0 "$TEST_ROOT/full-deploy.log" full
[[ -d "$TEST_ROOT/install/AmbientSpace.app" ]]
grep -q 'trackRow-' "$TEST_ROOT/osascript.log"
grep -q 'AXIdentifier' "$TEST_ROOT/osascript.log"
if grep -q 'Volume and audio mode' "$TEST_ROOT/osascript.log"; then
    printf '%s\n' 'The deployment interaction must not depend on the English volume label.' >&2
    exit 1
fi

printf '%s\n' 'Mac deployment contract tests passed.'
