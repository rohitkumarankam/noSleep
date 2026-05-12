#!/usr/bin/env zsh
set -e

echo "Installing noSleep..."
echo ""

if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found."
    echo "Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Detect existing install so we can restart the daemon after upgrade.
LABEL="com.noSleep.daemon"
WAS_RUNNING=false
if /bin/launchctl list 2>/dev/null | grep -q "$LABEL"; then
    WAS_RUNNING=true
fi

echo "Compiling..."
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
TARGET_CPU=$(echo "$CPU_BRAND" | grep -oiE 'Apple M[0-9]+' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
COMPILED=false

if [[ -n "$TARGET_CPU" ]]; then
    echo "Detected CPU: $CPU_BRAND → Trying optimized build with -target-cpu $TARGET_CPU"
    
    # Try optimized compilation with error trapping and log to file
    if swiftc -O -target-cpu "$TARGET_CPU" Sources/noSleep/*.swift -o noSleep 2>/tmp/noSleep_compile_error.log; then
        echo "✓ Optimized compilation successful"
        COMPILED=true
    else
        echo "⚠️ Optimized compilation failed. Falling back to standard build..."
        cat /tmp/noSleep_compile_error.log
        rm -f /tmp/noSleep_compile_error.log
    fi
fi

# Fallback to standard compilation if optimized one failed or wasn't attempted
if [[ "$COMPILED" == false ]]; then
    echo "Compiling with standard settings..."
    if ! swiftc -O Sources/noSleep/*.swift -o noSleep 2>/tmp/noSleep_compile_error.log; then
        echo "❌ Compilation failed:"
        cat /tmp/noSleep_compile_error.log
        rm -f /tmp/noSleep_compile_error.log
        exit 1
    fi
    echo "✓ Standard compilation successful"
fi

mkdir -p ~/bin
cp noSleep ~/bin/noSleep
chmod +x ~/bin/noSleep

# Generate plist with expanded $HOME
PLIST_DEST=~/Library/LaunchAgents/com.noSleep.daemon.plist
cat > "$PLIST_DEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.noSleep.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/bin/noSleep</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/noSleep.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/noSleep.err</string>
</dict>
</plist>
EOF

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo ""
    echo "Note: ~/bin is not in your PATH."
    echo "Add this to your ~/.zshrc:"
    echo '  export PATH="$HOME/bin:$PATH"'
fi

echo ""
echo "✓ Installed to ~/bin/noSleep"
echo "✓ Plist created at $PLIST_DEST"
echo ""

if [[ "$WAS_RUNNING" == true ]]; then
    echo "Existing daemon detected — restarting to pick up the new binary..."
    ~/bin/noSleep restart
else
    echo "To start: noSleep start"
    echo "To check: noSleep status"
fi
