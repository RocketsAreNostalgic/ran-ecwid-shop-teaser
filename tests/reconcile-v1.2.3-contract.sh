#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
workflow="$repo_root/.github/workflows/reconcile-v1.2.3.yml"

require() {
  local text=$1
  grep -Fq -- "$text" "$workflow" || {
    printf 'Missing v1.2.3 reconciliation contract: %s\n' "$text" >&2
    exit 1
  }
}

reject() {
  local text=$1
  if grep -Fq -- "$text" "$workflow"; then
    printf 'Forbidden v1.2.3 reconciliation contract: %s\n' "$text" >&2
    exit 1
  fi
}

require 'RAN_HISTORICAL_COMMIT: adfb601b7c8cb899310bad0d46c90e0c522f63d9'
require 'RAN_RELEASE_HEAD: 09e37fdc5df7f52f4d6da487c69bf21ab3162f3a'
require 'RAN_RELEASE_TREE: 4fd474af152c5944db2e6ef8b1a86ddcbdd4d9ff'
require "RAN_RELEASE_PR: '11'"
require 'RAN_RELEASE_TAG: v1.2.3'
require 'RAN_RELEASE_VERSION: 1.2.3'
require "github.sha == '395dabd0546459aeebf5ab3d28b646870e95fb5a'"
require 'group: release-please-main'
require 'git checkout --detach "$RAN_HISTORICAL_COMMIT"'
require "test \"\$(git rev-parse 'HEAD^{tree}')\" = \"\$RAN_RELEASE_TREE\""
require 'name: ran-ecwid-v1.2.3-reconciliation-${{ github.run_id }}'
require 'name: Historical v1.2.3 / PHP ${{ matrix.php }} / WordPress ${{ matrix.wordpress }}'
require "wordpress: '6.5'"
require "wordpress: '7.0.3'"
require 'wp plugin check ran-ecwid-shop-teaser'
require 'image: mysql:8.0@sha256:7dcddc01f13bab2f15cde676d44d01f61fc9f99fe7785e86196dfc07d358ae2b'
require 'https://raw.githubusercontent.com/wp-cli/scaffold-command/4a464898bf96f9d5e19e9f04957a702bf9bdc191/templates/install-wp-tests.sh'
require 'remote_digest="$(jq -r '\''.[0].digest // ""'\'' <<< "$matches")"'
require 'composer lint:compat'

rebuild=$(awk '
  /^    rebuild:$/ { capture = 1 }
  /^    compatibility:$/ { capture = 0 }
  capture { print }
' "$workflow")
compat=$(awk '
  /^    compatibility:$/ { capture = 1 }
  /^    publish:$/ { capture = 0 }
  capture { print }
' "$workflow")
publisher=$(awk '
  /^    publish:$/ { capture = 1 }
  capture { print }
' "$workflow")
test -n "$rebuild" && test -n "$compat" && test -n "$publisher"

grep -Fq 'permissions: {}' <<< "$rebuild"
grep -Fq 'permissions: {}' <<< "$compat"
if grep -Eq 'GH_TOKEN|GITHUB_TOKEN|secrets\.GITHUB_TOKEN' <<< "$rebuild"; then
  echo 'Historical rebuild acquired repository token authority.' >&2
  exit 1
fi
if grep -Eq 'GH_TOKEN|GITHUB_TOKEN|secrets\.GITHUB_TOKEN' <<< "$compat"; then
  echo 'Historical compatibility proof acquired repository token authority.' >&2
  exit 1
fi

grep -Fq 'contents: write' <<< "$publisher"
grep -Fq 'actions: read' <<< "$publisher"
grep -Fq 'issues: write' <<< "$publisher"
if grep -Fq 'actions/checkout@' <<< "$publisher"; then
  echo 'Write-capable reconciliation publisher must remain source-free.' >&2
  exit 1
fi
if grep -Eq 'pnpm install|composer install|scripts/create-release-assets\.sh' <<< "$publisher"; then
  echo 'Write-capable reconciliation publisher must not execute historical build code.' >&2
  exit 1
fi

test "$(grep -Fc 'resolve_tag_commit() {' <<< "$publisher")" -ge 3
test "$(grep -Fc 'test "$(resolve_tag_commit "$tag_ref")" = "$RAN_HISTORICAL_COMMIT"' <<< "$publisher")" -ge 3

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'state=awaiting-tag'
require "case \"\$tag_http_status\" in"
require '404)'
require '::error::Unable to read exact historical tag state (HTTP ${tag_http_status}).'
reject '2>/dev/null || true'
require '::notice::Historical v1.2.3 is fully qualified and awaiting exact owner-created tag'
require 'After the tag exists, rerun only this publisher job'
require "if: steps.identity.outputs.state != 'awaiting-tag'"
reject '::error::Historical v1.2.3 is fully qualified. Create exact tag'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(awk '/state=awaiting-tag/ { print NR; exit }' "$workflow")
draft_create=$(awk '/Create exact draft release from the pre-existing verified tag/ { print NR; exit }' "$workflow")
readback=$(awk '/Read back exact tag, release, assets, and digests/ { print NR; exit }' "$workflow")
labels=$(awk '/Reconcile Release Please PR labels only after exact publication readback/ { print NR; exit }' "$workflow")
test -n "$tag_guard" && test -n "$draft_create" && test -n "$readback" && test -n "$labels"
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
