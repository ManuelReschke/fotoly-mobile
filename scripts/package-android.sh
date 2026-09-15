#!/usr/bin/env bash
# Copy flavor release APK + AAB into dist/ with versioned names.
set -euo pipefail

flavor="${FLAVOR:-fotoly}"
version="${VERSION:-}"
if [[ -z "$version" ]]; then
  echo "VERSION is required (e.g. VERSION=1.2.3 $0)" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
dist="${root}/dist"
mkdir -p "$dist"

apk_src="${root}/build/app/outputs/flutter-apk/app-${flavor}-release.apk"
aab_src="${root}/build/app/outputs/bundle/${flavor}Release/app-${flavor}-release.aab"

if [[ ! -f "$apk_src" ]]; then
  echo "missing APK: ${apk_src}" >&2
  exit 1
fi
if [[ ! -f "$aab_src" ]]; then
  echo "missing AAB: ${aab_src}" >&2
  exit 1
fi

cp -f "$apk_src" "${dist}/${flavor}-${version}.apk"
cp -f "$aab_src" "${dist}/${flavor}-${version}.aab"

echo "APK: ${dist}/${flavor}-${version}.apk"
echo "AAB: ${dist}/${flavor}-${version}.aab"
ls -lh "${dist}/${flavor}-${version}.apk" "${dist}/${flavor}-${version}.aab"
