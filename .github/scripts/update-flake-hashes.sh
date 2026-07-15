#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION must be set, for example v0.2.3}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"

version="${VERSION#v}"
checksums="$RUNNER_TEMP/checksums.txt"

checksum_for() {
  local asset="$1"
  awk -v asset="$asset" '$2 == asset { print $1; exit }' "$checksums"
}

replace_hash() {
  local asset="$1"
  local hash="$2"
  test "${#hash}" -eq 64
  ASSET="$asset" HASH="$hash" perl -0pi -e '
    my $asset = quotemeta($ENV{ASSET});
    s/(asset = "${asset}";\n\s+sha256 = ")[^"]+("\s*;)/$1$ENV{HASH}$2/;
  ' flake.nix
}

grep -q "version = \"$version\";" flake.nix
replace_hash 'aicomiter_${version}_linux_x86_64.tar.gz' \
  "$(checksum_for "aicomiter_${version}_linux_x86_64.tar.gz")"
replace_hash 'aicomiter_${version}_linux_arm64.tar.gz' \
  "$(checksum_for "aicomiter_${version}_linux_arm64.tar.gz")"
replace_hash 'aicomiter_${version}_macOS_x86_64.tar.gz' \
  "$(checksum_for "aicomiter_${version}_macOS_x86_64.tar.gz")"
replace_hash 'aicomiter_${version}_macOS_arm64.tar.gz' \
  "$(checksum_for "aicomiter_${version}_macOS_arm64.tar.gz")"
