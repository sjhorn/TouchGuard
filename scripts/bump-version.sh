#!/usr/bin/env bash
# Sets MARKETING_VERSION for every target. Usage: scripts/bump-version.sh 2.0.1
set -euo pipefail

version=${1:?usage: $0 <major.minor.patch>}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must look like 2.0.1" >&2; exit 1; }

root=$(cd "$(dirname "$0")/.." && pwd)
pbxproj="$root/TouchGuard.xcodeproj/project.pbxproj"

sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $version;/" "$pbxproj"
echo "MARKETING_VERSION is now $version ($(grep -c "MARKETING_VERSION = $version;" "$pbxproj") build configurations)."
echo "Next: add a $version section to CHANGELOG.md, commit, then tag v$version."
