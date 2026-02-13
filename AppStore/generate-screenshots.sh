#!/bin/bash
#
# generate-screenshots.sh
# Automates screenshot generation for trainTime across all languages and device sizes
#

set -e

PROJECT_DIR="/Users/darrylcauldwell/Library/Mobile Documents/com~apple~CloudDocs/Development/trainTime"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"

# Languages to generate screenshots for
LANGUAGES=("en" "cy" "fr" "de" "es")

# Device simulators (App Store required sizes)
DEVICES=(
    "iPhone 17 Pro Max"     # 6.7" display
    "iPhone 17 Pro"         # 6.3" display
)

echo "🚂 trainTime Screenshot Generation"
echo "=================================="
echo ""

# Clean output directory
if [ -d "$OUTPUT_DIR" ]; then
    echo "🧹 Cleaning previous screenshots..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# Build the project first
echo "🔨 Building project..."
cd "$PROJECT_DIR"
xcodebuild -project trainTime.xcodeproj -scheme trainTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build-for-testing > /dev/null 2>&1
echo "✅ Build complete"
echo ""

# Generate screenshots for each language and device
for lang in "${LANGUAGES[@]}"; do
    echo "📸 Generating screenshots for language: $lang"

    for device in "${DEVICES[@]}"; do
        echo "  📱 Device: $device"

        DERIVED_DATA="$OUTPUT_DIR/DerivedData-$lang-$(echo $device | tr ' ' '-')"

        # Run tests
        xcodebuild test \
            -project trainTime.xcodeproj \
            -scheme trainTime \
            -destination "platform=iOS Simulator,name=$device" \
            -testLanguage "$lang" \
            -derivedDataPath "$DERIVED_DATA" \
            2>&1 | grep -E "(Test Suite|Testing|PASS|FAIL)" || true

        # Extract screenshots from test results
        ATTACHMENTS_DIR="$DERIVED_DATA/Logs/Test/Attachments"
        if [ -d "$ATTACHMENTS_DIR" ]; then
            DEVICE_DIR=$(echo $device | tr ' ' '-')
            TARGET_DIR="$OUTPUT_DIR/$lang/$DEVICE_DIR"
            mkdir -p "$TARGET_DIR"

            # Copy and rename screenshots
            find "$ATTACHMENTS_DIR" -name "*.png" -type f | sort | while read screenshot; do
                filename=$(basename "$screenshot")
                # Extract screenshot name from XCTest attachment naming
                # Format: {lang}-{device}-{name}_*.png
                if [[ $filename =~ ([0-9]{2}-[a-z-]+) ]]; then
                    screenshot_name="${BASH_REMATCH[1]}.png"
                    cp "$screenshot" "$TARGET_DIR/$screenshot_name"
                fi
            done

            screenshot_count=$(find "$TARGET_DIR" -name "*.png" | wc -l | tr -d ' ')
            echo "    ✅ $screenshot_count screenshots saved to $TARGET_DIR"
        fi
    done
    echo ""
done

# Summary
echo "=================================="
echo "✅ Screenshot generation complete!"
echo ""
echo "📂 Output directory: $OUTPUT_DIR"
echo ""
echo "Screenshots organized by:"
echo "  $OUTPUT_DIR/{language}/{device}/"
echo ""
echo "Example: $OUTPUT_DIR/en/iPhone-15-Pro-Max/01-search-initial.png"
echo ""

# Count total screenshots
total_count=$(find "$OUTPUT_DIR" -name "*.png" | wc -l | tr -d ' ')
echo "📊 Total screenshots generated: $total_count"
echo ""
echo "Next steps:"
echo "1. Review screenshots in $OUTPUT_DIR"
echo "2. Upload to App Store Connect for each language"
echo "3. Follow the submission checklist in AppStore/SUBMISSION_CHECKLIST.md"
