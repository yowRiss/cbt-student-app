#!/usr/bin/env bash
# Script mudah untuk menghubungkan ADB ke Waydroid dan menjalankan Flutter CBT

export JAVA_HOME="$HOME/.jdk/temurin-21"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

WAYDROID_IP=$(waydroid status 2>/dev/null | grep "IP address" | awk '{print $3}')

if [ -n "$WAYDROID_IP" ]; then
    echo "🔗 Menghubungkan ADB ke Waydroid ($WAYDROID_IP:5555)..."
    adb connect "$WAYDROID_IP:5555"
fi

echo "🚀 Menjalankan Flutter CBT..."
flutter run
