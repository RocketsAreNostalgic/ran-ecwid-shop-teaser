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

rebuild_start=$(grep -n '^    rebuild: "$workflow" | cut -d: -f1)
compat_start=$(grep -n '^    compatibility: "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^    publish: "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
compat_start=$(grep -n '^  compatibility:$' "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
compat_start=$(grep -n '^  compatibility:$' "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
compat_start=$(grep -n '^  compatibility:$' "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
 "$workflow" | cut -d: -f1)
compat_start=$(grep -n '^  compatibility:$' "$workflow" | cut -d: -f1)
publish_start=$(grep -n '^  publish:$' "$workflow" | cut -d: -f1)
test -n "$rebuild_start" && test -n "$compat_start" && test -n "$publish_start"
test "$rebuild_start" -lt "$compat_start"
test "$compat_start" -lt "$publish_start"

rebuild=$(sed -n "${rebuild_start},$((compat_start - 1))p" "$workflow")
compat=$(sed -n "${compat_start},$((publish_start - 1))p" "$workflow")
publisher=$(sed -n "${publish_start},\$p" "$workflow")

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

require 'live_main="$(gh api'
require 'git/ref/heads/main'
require '.merge_commit_sha == $merge'
require '.head.sha == $head'
require '.user.login == "github-actions[bot]"'
require 'Historical v1.2.3 is fully qualified. Create exact tag ${RAN_RELEASE_TAG} at ${RAN_HISTORICAL_COMMIT}'
require 'git/ref/tags/${RAN_RELEASE_TAG}'
reject '--method POST "repos/${GITHUB_REPOSITORY}/git/refs"'
reject 'gh release create'
require 'Create exact draft release from the pre-existing verified tag'
require 'releases/${RELEASE_ID}/assets?name=${asset_name}'
require 'Read back exact tag, release, assets, and digests'
require 'Reconcile Release Please PR labels only after exact publication readback'

tag_guard=$(grep -n 'Historical v1.2.3 is fully qualified. Create exact tag' "$workflow" | cut -d: -f1)
draft_create=$(grep -n 'Create exact draft release from the pre-existing verified tag' "$workflow" | cut -d: -f1)
readback=$(grep -n 'Read back exact tag, release, assets, and digests' "$workflow" | cut -d: -f1)
labels=$(grep -n 'Reconcile Release Please PR labels only after exact publication readback' "$workflow" | cut -d: -f1)
test "$tag_guard" -lt "$draft_create"
test "$draft_create" -lt "$readback"
test "$readback" -lt "$labels"
