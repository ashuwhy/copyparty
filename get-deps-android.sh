#!/bin/bash
# 
# Download and extract web dependencies for copyparty on Android/Termux
# This script downloads the pre-built dependencies from GitHub instead of building with Docker
#

set -e

echo "🤖 Copyparty Android/Termux Dependency Downloader"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "copyparty/__init__.py" ]; then
    echo "❌ Error: Please run this script from the copyparty project root directory"
    echo "   (The directory that contains copyparty/ folder)"
    exit 1
fi

# Create deps directory if it doesn't exist
mkdir -p copyparty/web/deps

# Check if deps already exist
if [ -f "copyparty/web/deps/marked.js.gz" ]; then
    echo "✅ Dependencies already exist in copyparty/web/deps/"
    echo "   If you want to re-download, delete the deps folder first:"
    echo "   rm -rf copyparty/web/deps"
    exit 0
fi

echo "📥 Downloading latest copyparty-sfx.py from GitHub..."
url="https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py"
tmp_sfx="tmp_copyparty_sfx.py"

# Download the SFX file
if command -v wget >/dev/null 2>&1; then
    wget -O "$tmp_sfx" "$url"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$tmp_sfx" "$url"
else
    echo "❌ Error: Neither wget nor curl found. Please install one of them:"
    echo "   pkg install wget"
    exit 1
fi

echo "🔍 Extracting web dependencies..."

# Run the SFX to extract dependencies
python3 "$tmp_sfx" --version >/dev/null 2>&1 || {
    echo "❌ Error: Failed to run downloaded copyparty-sfx.py"
    rm -f "$tmp_sfx"
    exit 1
}

# Get the temporary directory where SFX extracted files
wdsrc=$(python3 "$tmp_sfx" --version 2>&1 | awk '/sfxdir:/{sub(/.*: /,"");print;exit}')

if [ -z "$wdsrc" ]; then
    echo "❌ Error: Could not find extraction directory from copyparty-sfx.py"
    rm -f "$tmp_sfx"
    exit 1
fi

if [ ! -d "$wdsrc/copyparty/web/deps" ]; then
    echo "❌ Error: Dependencies not found in extracted files"
    rm -f "$tmp_sfx"
    exit 1
fi

echo "📋 Copying dependencies to copyparty/web/deps/..."
cp -R "$wdsrc/copyparty/web/deps"/* copyparty/web/deps/

# Create __init__.py if it doesn't exist
touch copyparty/web/deps/__init__.py

# Cleanup
rm -f "$tmp_sfx"

echo "✅ Success! Web dependencies installed:"
echo "   $(ls -1 copyparty/web/deps/ | wc -l) files in copyparty/web/deps/"
echo ""
echo "📱 Dependencies ready for Android/Termux!"
echo "   You can now run copyparty with full web functionality."
echo ""
echo "🚀 To start copyparty:"
echo "   python3 -m copyparty"