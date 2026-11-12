#!/usr/bin/env bash
# Compiles a library's flag reader and an app's flag overrides against react-native's ReactCommon headers at main
# (or the ref the first argument names), once plain and once with -DRN_STRICT_API, the strict C++ API opt-in.
# Exits 1 while a strict compile stops on the private-header #error, 0 once both compile under RN_STRICT_API,
# and 2 when a step fails or a plain compile fails.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
sources="${here}/ReproducerApp/cpp"
ref=${1:-main}
compiler=${CXX:-c++}
work=$(mktemp -d)
if command -v cygpath > /dev/null; then
  work=$(cygpath -m "${work}")
  sources=$(cygpath -m "${sources}")
fi
trap 'rm -rf "${work}"' EXIT
step() { echo "== $*"; }
finish() { echo "SUMMARY: $2"; exit "$1"; }
fail() { echo "step failed: $*"; finish 2 "the reproduction stopped: $*"; }

step "toolchain"
"${compiler}" --version | head -n 1 || fail "${compiler}"

step "react-native at ${ref}"
git clone --quiet --depth 1 --branch "${ref}" --filter=blob:none --sparse https://github.com/react/react-native.git "${work}/react-native" || fail "git clone"
git -C "${work}/react-native" sparse-checkout set packages/react-native/ReactCommon/react/featureflags packages/react-native/ReactCommon/react/cxxstableapi || fail "sparse-checkout"
commit=$(git -C "${work}/react-native" rev-parse HEAD) || fail "rev-parse"
echo "react/react-native ${commit}"
common="${work}/react-native/packages/react-native/ReactCommon"

step "which headers in react/featureflags include PrivateGuard.h"
for header in "${common}"/react/featureflags/*.h; do
  if grep -q "cxxstableapi/PrivateGuard.h" "${header}"; then echo "private: ${header##*/}"; else echo "not private: ${header##*/}"; fi
done

step "which flags ReactNativePublicFeatureFlags.h declares"
public="${common}/react/featureflags/ReactNativePublicFeatureFlags.h"
[[ -f "${public}" ]] || fail "no ReactNativePublicFeatureFlags.h"
grep -E '^class ' "${public}"
for flag in preventShadowTreeCommitExhaustion enableFabricCommitBranching updateRuntimeShadowNodeReferencesOnCommit cxxNativeAnimatedEnabled enableFlexboxAutoMinSizeInStrictMode; do
  if grep -q "static bool ${flag}()" "${public}"; then echo "${flag}: declared"; else echo "${flag}: not declared"; fi
done

refused=0
for source in FlagReader.cpp FlagOverrides.cpp; do
  step "${source} without RN_STRICT_API"
  "${compiler}" -std=c++20 -fsyntax-only -I "${common}" "${sources}/${source}" > "${work}/plain.log" 2>&1 || {
    cat "${work}/plain.log"
    fail "${source} does not compile without RN_STRICT_API"
  }
  echo "compiles"
  step "${source} with -DRN_STRICT_API"
  if "${compiler}" -std=c++20 -fsyntax-only -DRN_STRICT_API -I "${common}" "${sources}/${source}" > "${work}/strict.log" 2>&1; then
    echo "compiles"
  elif grep -q 'This is a private React Native header' "${work}/strict.log"; then
    grep -E 'error:' "${work}/strict.log" | sed -E 's#^.*ReactCommon[/\\]##' | sort -u
    refused=$((refused + 1))
  else
    cat "${work}/strict.log"
    fail "${source} fails under RN_STRICT_API for another reason"
  fi
done

if ((refused > 0)); then
  finish 1 "under RN_STRICT_API ${refused} of 2 files stop on the private-header #error: no feature-flag header is public (react/react-native ${commit:0:10})"
fi
finish 0 "both files compile under RN_STRICT_API (react/react-native ${commit:0:10})"
