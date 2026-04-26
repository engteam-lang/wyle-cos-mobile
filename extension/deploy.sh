#!/bin/bash

# 1. Get the directory where THIS script lives (the extension folder)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 2. Get the root project directory (one level up from extension)
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "🚀 Starting build in $PROJECT_ROOT..."

# 3. Build Flutter from the root
cd "$PROJECT_ROOT"
flutter build web --release

# 4. Prepare the extension/flutter folder (CLEAN FIRST)
echo "📂 Cleaning and organizing files in $SCRIPT_DIR/flutter..."
mkdir -p "$SCRIPT_DIR/flutter"
rm -rf "$SCRIPT_DIR/flutter/*"

# 5. Copy all build files
cp -r "$PROJECT_ROOT/build/web/"* "$SCRIPT_DIR/flutter/"

# 6. DOUBLE CHECK CanvasKit is local (Crucial for CSP)
mkdir -p "$SCRIPT_DIR/flutter/canvaskit"
cp -r "$PROJECT_ROOT/build/web/canvaskit/"* "$SCRIPT_DIR/flutter/canvaskit/"

# 7. Clean up PWA manifest (prevents Chrome conflicts)
rm -f "$SCRIPT_DIR/flutter/manifest.json"

echo "✅ Success! Flutter build copied to extension/flutter"