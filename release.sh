#!/usr/bin/env bash
set -e

export JAVA_HOME="$HOME/.jdk/temurin-21"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# ==============================================================================
# Helper Script: Buat Rilis & Memicu GitHub Actions untuk Build APK Otomatis
# Contoh: ./release.sh 1.0.1 "Perbaikan tampilan soal dan stabilitas jaringan"
# ==============================================================================

NEW_VERSION="$1"
NOTES="${2:-Pembaruan aplikasi CBT Siswa}"

if [ -z "$NEW_VERSION" ]; then
    echo "❌ Error: Harap masukkan nomor versi rilis."
    echo "Contoh penggunaan:"
    echo "  ./release.sh 1.0.1 \"Perbaikan auto update dan performa\""
    exit 1
fi

# Buang awalan 'v' jika ada
CLEAN_VERSION="${NEW_VERSION#v}"
TAG="v$CLEAN_VERSION"

echo "=========================================================="
echo "🚀 Mempersiapkan Rilis CBT Mobile: $TAG"
echo "=========================================================="

# 1. Update versi di AppConstants.dart
sed -i "s/static const String appVersion = '.*';/static const String appVersion = '$CLEAN_VERSION';/" lib/core/constants/app_constants.dart

# 2. Update versi di pubspec.yaml
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | cut -d'+' -f2)
NEXT_BUILD=$((CURRENT_BUILD + 1))
sed -i "s/^version: .*/version: $CLEAN_VERSION+$NEXT_BUILD/" pubspec.yaml

echo "✅ Versi diperbarui menjadi $CLEAN_VERSION+$NEXT_BUILD di pubspec.yaml dan app_constants.dart"

# 3. Jalankan flutter analyze untuk memastikan tidak ada error kode
echo "🔍 Menjalankan analisa kode..."
flutter analyze

# 4. Commit dan buat Git Tag
git add .
git commit -m "chore(release): bump version to $TAG" || echo "Tidak ada perubahan file baru."
git tag -a "$TAG" -m "$NOTES"

echo "📤 Mendorong tag ke GitHub ($TAG)..."
git push origin HEAD --tags

echo "=========================================================="
echo "🎉 Berhasil! Tag $TAG telah didorong ke GitHub."
echo "GitHub Actions sekarang sedang otomatis mengompilasi APK (Split ARM64, ARMeabi-v7a, x86_64, dan Universal)."
echo "Pantau proses build di:"
echo "  https://github.com/yowRiss/cbt-student-app/actions"
echo "Setelah selesai, file APK siap diunduh di:"
echo "  https://github.com/yowRiss/cbt-student-app/releases/tag/$TAG"
echo "=========================================================="
