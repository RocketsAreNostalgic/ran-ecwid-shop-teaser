#!/usr/bin/env bash
set -euo pipefail

fail() {
	printf 'validate-release-candidate: %s\n' "$*" >&2
	exit 1
}

[[ $# -eq 2 ]] || fail 'expected <base-commit> <release-commit>.'
base_commit=$(git rev-parse --verify "$1^{commit}") \
	|| fail 'base commit is unavailable.'
release_commit=$(git rev-parse --verify "$2^{commit}") \
	|| fail 'release commit is unavailable.'

git merge-base --is-ancestor "$base_commit" "$release_commit" \
	|| fail 'release commit does not descend from its pull-request base.'
[[ "$(git rev-parse "${release_commit}^")" == "$base_commit" ]] \
	|| fail 'release candidate must be the single generated commit directly above its pull-request base.'

expected_changes=$(printf '%s\n' \
	$'M\t.release-please-manifest.json' \
	$'M\tCHANGELOG.md' \
	$'M\tlanguages/ran-ecwid-shop-teaser.pot' \
	$'M\tpackage.json' \
	$'M\tran-ecwid-shop-teaser.php' \
	$'M\treadme.txt')
actual_changes=$(git diff --name-status --no-renames "$base_commit" "$release_commit" -- | LC_ALL=C sort -k2)
[[ "$actual_changes" == "$expected_changes" ]] \
	|| fail 'release candidate must change exactly the six generated release files.'

manifest_version() {
	git show "$1:.release-please-manifest.json" \
		| jq -er 'select(type == "object" and keys == ["."] and (.["."] | type) == "string") | .["."]'
}

plugin_version() {
	git show "$1:ran-ecwid-shop-teaser.php" \
		| sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([^[:space:]]+).*/\1/p'
}

runtime_version() {
	git show "$1:ran-ecwid-shop-teaser.php" \
		| sed -nE "s/^define\( 'RAN_ECWID_SHOP_TEASER_VERSION', '([^']+)' \);.*$/\1/p"
}

stable_tag() {
	git show "$1:readme.txt" \
		| sed -nE 's/^Stable tag:[[:space:]]*([^[:space:]]+).*/\1/p'
}

package_version() {
	git show "$1:package.json" | jq -er '.version | select(type == "string")'
}

pot_version() {
	git show "$1:languages/ran-ecwid-shop-teaser.pot" \
		| sed -nE 's/^"Project-Id-Version: RAN Ecwid Shop Teaser ([^\\]+)\\n"$/\1/p'
}

base_version=$(manifest_version "$base_commit") \
	|| fail 'base manifest has an invalid shape.'
release_version=$(manifest_version "$release_commit") \
	|| fail 'release manifest has an invalid shape.'
[[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
	|| fail 'release version is not valid semver.'
[[ "$release_version" != "$base_version" ]] \
	|| fail 'release version did not change.'

for value in \
	"$(plugin_version "$base_commit")" \
	"$(runtime_version "$base_commit")" \
	"$(stable_tag "$base_commit")" \
	"$(package_version "$base_commit")" \
	"$(pot_version "$base_commit")"; do
	[[ "$value" == "$base_version" ]] \
		|| fail 'a base version source disagrees with the base manifest.'
done

for value in \
	"$(plugin_version "$release_commit")" \
	"$(runtime_version "$release_commit")" \
	"$(stable_tag "$release_commit")" \
	"$(package_version "$release_commit")" \
	"$(pot_version "$release_commit")"; do
	[[ "$value" == "$release_version" ]] \
		|| fail 'a release version source disagrees with the release manifest.'
done

normalize_plugin() {
	git show "$1:ran-ecwid-shop-teaser.php" \
		| sed -E \
			-e 's/^([[:space:]]*\*[[:space:]]*Version:).*/\1 __RELEASE_VERSION__/' \
			-e "s/^(define\( 'RAN_ECWID_SHOP_TEASER_VERSION', )'[^']+'( \);.*)$/\1'__RELEASE_VERSION__'\2/"
}

diff -u <(normalize_plugin "$base_commit") <(normalize_plugin "$release_commit") >/dev/null \
	|| fail 'plugin bootstrap changed beyond the generated version values.'

diff -u \
	<(git show "$base_commit:readme.txt" | sed -E 's/^(Stable tag:).*/\1 __RELEASE_VERSION__/') \
	<(git show "$release_commit:readme.txt" | sed -E 's/^(Stable tag:).*/\1 __RELEASE_VERSION__/') \
	>/dev/null \
	|| fail 'readme changed beyond the generated Stable tag value.'

diff -u \
	<(git show "$base_commit:package.json" | jq '.version = "__RELEASE_VERSION__"') \
	<(git show "$release_commit:package.json" | jq '.version = "__RELEASE_VERSION__"') \
	>/dev/null \
	|| fail 'package.json changed beyond the generated version value.'

normalize_pot() {
	git show "$1:languages/ran-ecwid-shop-teaser.pot" \
		| sed -E 's/^("Project-Id-Version: RAN Ecwid Shop Teaser )[^\\]+(\\n")$/\1__RELEASE_VERSION__\2/'
}

diff -u <(normalize_pot "$base_commit") <(normalize_pot "$release_commit") >/dev/null \
	|| fail 'translation template changed beyond the generated project version.'

read -r changelog_additions changelog_deletions changelog_path \
	< <(git diff --numstat "$base_commit" "$release_commit" -- CHANGELOG.md)
[[ "$changelog_path" == 'CHANGELOG.md' \
	&& "$changelog_additions" =~ ^[1-9][0-9]*$ \
	&& "$changelog_deletions" == 0 ]] \
	|| fail 'changelog must preserve all accepted history and add the new release entry.'
release_changelog=$(git show "$release_commit:CHANGELOG.md")
grep -Fq "## [${release_version}](" <<< "$release_changelog" \
	|| fail 'changelog does not contain the proposed release heading.'
release_heading_line=$(grep -nF -m1 "## [${release_version}](" <<< "$release_changelog" | cut -d: -f1)
first_heading_line=$(grep -nE -m1 '^## \[[0-9]+\.[0-9]+\.[0-9]+' <<< "$release_changelog" | cut -d: -f1)
[[ -n "$release_heading_line" && "$release_heading_line" == "$first_heading_line" ]] \
	|| fail 'new release entry must remain the first version section in the changelog.'

printf 'Validated Release Please candidate %s at %s.\n' "$release_version" "$release_commit"
