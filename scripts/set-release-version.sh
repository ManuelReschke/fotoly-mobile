#!/usr/bin/env bash
# Stamp pubspec.yaml + AppInfo from a git tag (vX.Y.Z or vX.Y.Z-prerelease).
# Build number defaults to GITHUB_RUN_NUMBER, then 1.
set -euo pipefail

tag="${1:-${GITHUB_REF_NAME:-}}"
build="${2:-${GITHUB_RUN_NUMBER:-1}}"
if [[ -z "$tag" ]]; then
  echo "usage: $0 vX.Y.Z [build_number]" >&2
  exit 1
fi

version="${tag#v}"
core="${version%%-*}"
if [[ ! "$core" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "tag must be vX.Y.Z (got ${tag})" >&2
  exit 1
fi
if [[ ! "$build" =~ ^[0-9]+$ ]]; then
  echo "build number must be an integer (got ${build})" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
pubspec="${root}/pubspec.yaml"
app_info="${root}/lib/config/app_info.dart"

if [[ ! -f "$pubspec" || ! -f "$app_info" ]]; then
  echo "expected pubspec.yaml and lib/config/app_info.dart under ${root}" >&2
  exit 1
fi

sed -i -E "s/^version: .*/version: ${version}+${build}/" "$pubspec"
sed -i -E "s/static const String version = '[^']*';/static const String version = '${version}';/" "$app_info"
sed -i -E "s/static const String buildNumber = '[^']*';/static const String buildNumber = '${build}';/" "$app_info"

if ! grep -q "^version: ${version}+${build}\$" "$pubspec"; then
  echo "failed to stamp pubspec.yaml" >&2
  exit 1
fi
if ! grep -q "static const String version = '${version}';" "$app_info"; then
  echo "failed to stamp AppInfo.version" >&2
  exit 1
fi
if ! grep -q "static const String buildNumber = '${build}';" "$app_info"; then
  echo "failed to stamp AppInfo.buildNumber" >&2
  exit 1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "VERSION=${version}"
    echo "VERSION_CORE=${core}"
    echo "BUILD_NUMBER=${build}"
  } >> "$GITHUB_ENV"
fi

echo "version=${version} versionCode=${build}"
