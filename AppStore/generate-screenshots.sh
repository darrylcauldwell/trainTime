#!/bin/bash
#
# generate-screenshots.sh
# Generates App Store screenshots by running UI tests on required simulators
# and extracting PNG attachments from the xcresult bundles.
#

set -e

PROJECT_DIR="/Users/darrylcauldwell/Library/Mobile Documents/com~apple~CloudDocs/Development/LiveRail"
SCREENSHOTS_DIR="$PROJECT_DIR/Screenshots"
FASTLANE_DIR="$PROJECT_DIR/fastlane/screenshots"

locale_for() {
    case "$1" in
        en) echo "en-GB" ;;
        fr) echo "fr-FR" ;;
        de) echo "de-DE" ;;
        es) echo "es-ES" ;;
        *)  echo "" ;;
    esac
}

# ── Extract PNGs from an xcresult bundle ──────────────────────────────────────
extract_pngs() {
    local xcresult="$1"
    local out_dir="$2"
    mkdir -p "$out_dir"

    if [ ! -d "$xcresult" ]; then
        echo "    WARNING: no xcresult at $xcresult"
        return 0
    fi

    local count=0
    local idx=0
    while IFS= read -r blob; do
        local magic
        magic=$(xxd -p -l 4 "$blob" 2>/dev/null | tr -d ' \n')
        if [ "$magic" = "89504e47" ]; then
            idx=$((idx + 1))
            local dest="$out_dir/screenshot-$(printf '%02d' $idx).png"
            cp "$blob" "$dest"
            count=$((count + 1))
        fi
    done < <(find "$xcresult/Data" -type f 2>/dev/null | sort)

    echo "    Extracted: $count PNG(s)"
}

# ── Run tests for one locale + device combination ─────────────────────────────
run_tests() {
    local lang="$1"
    local device="$2"
    local label="$3"
    local locale
    locale=$(locale_for "$lang")

    echo "  [$device / ${locale:-skipped}]"

    local xcresult="$SCREENSHOTS_DIR/results-${lang}-${label}.xcresult"

    xcodebuild \
        -xctestrun "$XCTESTRUN" \
        -destination "platform=iOS Simulator,name=$device" \
        -testLanguage "$lang" \
        -resultBundlePath "$xcresult" \
        -only-testing:LiveRailUITests \
        test-without-building \
        2>&1 | grep -E "(Test Suite|Test Case|passed|failed|error:)" || true

    local raw="$SCREENSHOTS_DIR/raw-${lang}-${label}"
    extract_pngs "$xcresult" "$raw"

    if [ -z "$locale" ]; then
        echo "    Staging skipped (locale not supported)"
        return 0
    fi
    local fastlane_locale_dir="$FASTLANE_DIR/$locale"
    mkdir -p "$fastlane_locale_dir"
    local staged=0
    while IFS= read -r png; do
        dest="$fastlane_locale_dir/${label}-$(basename "$png")"
        cp "$png" "$dest"
        staged=$((staged + 1))
    done < <(find "$raw" -maxdepth 1 -name "*.png" -type f 2>/dev/null | sort)
    echo "    Staged: $staged → fastlane/screenshots/$locale/"
}

# ─────────────────────────────────────────────────────────────────────────────
echo "LiveRail Screenshot Generation"
echo "=================================="
cd "$PROJECT_DIR"

echo "Cleaning previous output..."
rm -rf "$SCREENSHOTS_DIR"
mkdir -p "$SCREENSHOTS_DIR"
rm -rf "$FASTLANE_DIR"
mkdir -p "$FASTLANE_DIR"

echo ""
echo "Building for testing..."
xcodebuild \
    -project LiveRail.xcodeproj \
    -scheme LiveRail \
    -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
    -derivedDataPath "$SCREENSHOTS_DIR/DerivedData-build" \
    build-for-testing \
    COMPILER_INDEX_STORE_ENABLE=NO \
    > /tmp/liverail-screenshot-build.log 2>&1 \
    && echo "Build succeeded." \
    || { echo "Build FAILED — see /tmp/liverail-screenshot-build.log"; exit 1; }

XCTESTRUN=$(find "$SCREENSHOTS_DIR/DerivedData-build/Build/Products" -name "*.xctestrun" | head -1)
if [ -z "$XCTESTRUN" ]; then
    echo "ERROR: No xctestrun file found after build-for-testing"
    exit 1
fi
echo "Using xctestrun: $(basename "$XCTESTRUN")"

echo ""
echo "Running tests..."
echo ""

for lang in en fr de es; do
    run_tests "$lang" "iPhone 17 Pro Max" "iPhone-17-Pro-Max"
    run_tests "$lang" "iPhone 17 Pro"     "iPhone-17-Pro"
    echo ""
done

echo "=================================="
total=$(find "$FASTLANE_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
echo "Done. $total screenshot(s) in fastlane/screenshots/"
echo ""
echo "Upload with:  cd \"$PROJECT_DIR\" && fastlane screenshots"
