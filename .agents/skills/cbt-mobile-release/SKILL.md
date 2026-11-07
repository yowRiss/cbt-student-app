---
name: cbt-mobile-release
description: "Use this skill whenever the AI agent finishes creating, modifying, fixing, or patching any code inside the mobile/ directory (Flutter CBT Student App). Automates post-change verification, version bumping, Git tagging, pushing to the yowRiss/cbt-student-app repository, and triggering the automated GitHub Actions CI/CD to build and publish the universal .apk release."
---

# CBT Mobile Auto-Release & Patch Skill

This skill defines the mandatory workflow the AI agent MUST execute immediately whenever it finishes making updates, fixes, or additions to the `mobile/` Flutter codebase.

## Workflow Execution Steps

### 1. Code Quality Verification
Before creating a release, ensure there are zero analysis errors or syntax bugs:
```bash
export JAVA_HOME="$HOME/.jdk/temurin-21"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

cd "mobile"
flutter analyze
```
If any errors or linter warnings are reported, fix them before proceeding.

### 2. Determine Next Version & Changelog
1. Check the current version in `mobile/lib/core/constants/app_constants.dart` and `mobile/pubspec.yaml`.
2. Determine the semantic version bump:
   - **Patch** (e.g., `1.0.0` -> `1.0.1`): For bug fixes, minor UI tweaks, anti-cheat adjustments, autosave improvements.
   - **Minor** (e.g., `1.0.1` -> `1.1.0`): For new features, new screen additions, new exam formats.
3. Formulate a clear, concise Indonesian changelog summary explaining what was added or patched.

### 3. Execute Automated Release Script
Run the automated release script inside `mobile/`:
```bash
cd "mobile"
./release.sh <new_version> "<changelog_summary>"
```
*Example:*
```bash
./release.sh 1.0.1 "Perbaikan auto-update GitHub Release dan optimasi autosave jawaban"
```

The script will automatically:
- Update `appVersion` in `lib/core/constants/app_constants.dart`
- Bump `version` and build number in `pubspec.yaml`
- Commit the changes to `main`
- Create an annotated Git tag `v<new_version>`
- Push the commit and tag to `https://github.com/yowRiss/cbt-student-app.git`

### 4. Monitor & Report to User
1. Check that the GitHub Actions build workflow has been triggered:
   ```bash
   gh run list --repo yowRiss/cbt-student-app --limit 1
   ```
2. Inform the user of the new release version and provide clickable links:
   - Release Tag: `https://github.com/yowRiss/cbt-student-app/releases/tag/v<new_version>`
   - Direct APK Download: `https://github.com/yowRiss/cbt-student-app/releases/download/v<new_version>/cbt-student-app-universal.apk`
   - Actions Build Monitor: `https://github.com/yowRiss/cbt-student-app/actions`
