#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_root/scripts/validate-release-candidate.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ran-ecwid-release-candidate.XXXXXX")

cleanup() {
	case "$test_root" in
		"${TMPDIR:-/tmp}"/ran-ecwid-release-candidate.*) rm -rf -- "$test_root" ;;
	esac
}
trap cleanup EXIT HUP INT TERM

write_plugin() {
	local version=$1
	local description=${2:-'Render an Ecwid product grid.'}
	printf '%s\n' \
		'<?php' \
		'/**' \
		' * Plugin Name: RAN Ecwid Shop Teaser' \
		" * Description: ${description}" \
		' * x-release-please-start-version' \
		" * Version: ${version}" \
		' * x-release-please-end' \
		' */' \
		'' \
		"define( 'RAN_ECWID_SHOP_TEASER_VERSION', '${version}' ); // x-release-please-version" \
		> ran-ecwid-shop-teaser.php
}

write_readme() {
	printf '%s\n' \
		'=== RAN Ecwid Shop Teaser ===' \
		'x-release-please-start-version' \
		"Stable tag: $1" \
		'x-release-please-end' \
		> readme.txt
}

write_manifest() {
	printf '{\n  ".": "%s"\n}\n' "$1" > .release-please-manifest.json
}

write_package() {
	printf '{\n  "name": "ran-ecwid-shop-teaser",\n  "version": "%s",\n  "private": true\n}\n' "$1" > package.json
}

write_pot() {
	mkdir -p languages
	printf '%s\n' \
		'# RAN Ecwid Shop Teaser translations.' \
		'msgid ""' \
		'msgstr ""' \
		"\"Project-Id-Version: RAN Ecwid Shop Teaser $1\\n\"" \
		> languages/ran-ecwid-shop-teaser.pot
}

write_changelog() {
	local version=$1
	local preserve_base=${2:-true}
	printf '# Changelog\n\n## [%s](https://example.test/compare/v1.0.0...v%s)\n\n* Release entry.\n' \
		"$version" "$version" > CHANGELOG.md
	if [[ "$preserve_base" == true ]]; then
		printf '\n## [1.0.0](https://example.test/releases/v1.0.0)\n\n* Accepted history.\n' >> CHANGELOG.md
	fi
}

write_release_files() {
	write_plugin "$1"
	write_readme "$1"
	write_manifest "$1"
	write_package "$1"
	write_pot "$1"
	write_changelog "$1" "${2:-true}"
}

commit_candidate() {
	git add .release-please-manifest.json CHANGELOG.md languages/ran-ecwid-shop-teaser.pot package.json ran-ecwid-shop-teaser.php readme.txt
	git commit -q -m 'chore(main): release candidate'
}

expect_failure() {
	if "$validator" "$@" >/dev/null 2>&1; then
		printf 'Expected candidate validation to fail: %s -> %s\n' "$1" "$2" >&2
		exit 1
	fi
}

cd "$test_root"
git init -q
git config user.name 'RAN Ecwid Tests'
git config user.email 'tests@example.test'

write_plugin '1.0.0'
write_readme '1.0.0'
write_manifest '1.0.0'
write_package '1.0.0'
write_pot '1.0.0'
printf '%s\n' \
	'# Changelog' \
	'' \
	'## [1.0.0](https://example.test/releases/v1.0.0)' \
	'' \
	'* Accepted history.' \
	> CHANGELOG.md
git add .
git commit -q -m 'chore(main): release 1.0.0'
base_commit=$(git rev-parse HEAD)

write_release_files '1.0.1'
commit_candidate
good_commit=$(git rev-parse HEAD)
"$validator" "$base_commit" "$good_commit" >/dev/null

git checkout -q -B stacked-candidate "$good_commit"
git commit -q --allow-empty -m 'unexpected stacked release commit'
expect_failure "$base_commit" HEAD

git checkout -q -B extra-path "$base_commit"
write_release_files '1.0.1'
printf 'unexpected\n' > unexpected.txt
git add .
git commit -q -m 'test extra path'
expect_failure "$base_commit" HEAD

git checkout -q -B changed-plugin "$base_commit"
write_release_files '1.0.1'
write_plugin '1.0.1' 'Changed runtime description.'
commit_candidate
expect_failure "$base_commit" HEAD

git checkout -q -B changed-package "$base_commit"
write_release_files '1.0.1'
jq '.description = "Unexpected generated change"' package.json > package.changed.json
mv package.changed.json package.json
commit_candidate
expect_failure "$base_commit" HEAD

git checkout -q -B deleted-history "$base_commit"
write_release_files '1.0.1' false
commit_candidate
expect_failure "$base_commit" HEAD

git checkout -q -B mismatched-version "$base_commit"
write_release_files '1.0.1'
write_plugin '1.0.2'
commit_candidate
expect_failure "$base_commit" HEAD

printf 'Release candidate contract tests passed.\n'
