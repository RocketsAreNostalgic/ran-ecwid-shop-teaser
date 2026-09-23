#!/usr/bin/env bash
# Verify a release bundle and deploy it to WordPress.org SVN.
set -euo pipefail

export LC_ALL=C
export TZ=UTC

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config="$root/wordpress-org/deployment.json"
archive=${1:?Usage: deploy-wordpress-org.sh <archive> <checksum> [--sync-assets]}
checksum=${2:?A SHA-256 file is required.}
shift 2

sync_assets=false
for argument in "$@"; do
	case "$argument" in
		--sync-assets) sync_assets=true ;;
		*) echo "Unknown deployment option: $argument" >&2; exit 1 ;;
	esac
done

enabled=$(jq -r '.enabled' "$config")
jq -e '.syncListingAssets | type == "boolean"' "$config" >/dev/null
sync_listing_assets=$(jq -r '.syncListingAssets' "$config")
if [ "$enabled" != true ]; then
	echo "Routine WordPress.org deployment is disabled in $config." >&2
	exit 1
fi

if [ "$sync_assets" = true ] && [ "$sync_listing_assets" != true ]; then
    echo 'Listing asset synchronization is disabled by the committed contract.' >&2
    exit 1
fi

wordpress_org_slug=$(jq -er '.wordpressOrgSlug | select(length > 0)' "$config")
package_slug=$(jq -er '.packageSlug' "$config")
main_plugin_file=$(jq -er '.mainPluginFile' "$config")
assets_directory=$(jq -er '.listingAssetsDirectory' "$config")
version="${archive##*/}"
version="${version#ran-ecwid-shop-teaser-}"
version="${version%.zip}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || exit 1
test "$(basename "$archive")" = "ran-ecwid-shop-teaser-${version}.zip"
test "$(basename "$checksum")" = "$(basename "$archive").sha256"
test "$(sed -n 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$root/$main_plugin_file")" = "$version"
test "$(jq -er '."." | select(type == "string")' "$root/.release-please-manifest.json")" = "$version"

(
	cd "$(dirname "$archive")"
	sha256sum --check "$(basename "$checksum")"
)

workdir=$(mktemp -d)
cleanup() {
	rm -rf "$workdir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

unzip -q "$archive" -d "$workdir/release"
if [ ! -f "$workdir/release/$package_slug/$main_plugin_file" ]; then
	echo 'The verified archive does not contain the configured main plugin file.' >&2
	exit 1
fi

: "${WORDPRESS_ORG_USERNAME:?WORDPRESS_ORG_USERNAME is required.}"
: "${WORDPRESS_ORG_PASSWORD:?WORDPRESS_ORG_PASSWORD is required.}"

svn_url="https://plugins.svn.wordpress.org/$wordpress_org_slug"
svn_checkout="$workdir/svn"
svn checkout --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD" "$svn_url" "$svn_checkout"

if svn ls "$svn_url/tags/$version" --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD" >/dev/null 2>&1; then
	svn export --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD" "$svn_url/tags/$version" "$workdir/published"
	if diff -qr "$workdir/published" "$workdir/release/$package_slug"; then
		echo "WordPress.org tag $version already contains the exact ZIP; deployment is complete."
		exit 0
	fi
	echo "WordPress.org tag $version exists with different bytes; refusing to replace it." >&2
	exit 1
fi

svn_tags=$(svn ls "$svn_url/tags" --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD")
latest_stable=$(printf '%s\n' "$svn_tags" | sed -nE 's#^([0-9]+\.[0-9]+\.[0-9]+)/$#\1#p' | sort -V | tail -n 1)
if [[ -n "$latest_stable" && "$(printf '%s\n%s\n' "$version" "$latest_stable" | sort -V | tail -n 1)" != "$version" ]]; then
	echo "WordPress.org already has newer stable tag $latest_stable; refusing to roll trunk back to $version." >&2
	exit 1
fi

trunk_plugin="$svn_checkout/trunk/$main_plugin_file"
if [[ -f "$trunk_plugin" ]]; then
	trunk_version=$(sed -n 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$trunk_plugin")
	[[ "$trunk_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
		echo 'Existing SVN trunk has an unrecognized plugin version.' >&2
		exit 1
	}
	if [[ -f "$svn_checkout/trunk/readme.txt" ]]; then
		trunk_stable=$(sed -n 's/^Stable tag:[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$svn_checkout/trunk/readme.txt")
		test "$trunk_stable" = "$trunk_version" || {
			echo 'Existing SVN trunk plugin and readme versions disagree.' >&2
			exit 1
		}
	fi
	if [[ "$trunk_version" == "$version" || "$(printf '%s\n%s\n' "$version" "$trunk_version" | sort -V | tail -n 1)" != "$version" ]]; then
		echo "WordPress.org trunk is already at $trunk_version; refusing to replace it with $version." >&2
		exit 1
	fi
elif [[ -n "$(find "$svn_checkout/trunk" -mindepth 1 -maxdepth 1 ! -name .svn -print -quit)" ]]; then
	echo 'Existing SVN trunk has no recognizable main plugin file.' >&2
	exit 1
fi

rsync -a --delete --exclude='.svn' "$workdir/release/$package_slug/" "$svn_checkout/trunk/"
while IFS= read -r missing_path; do
	[ -n "$missing_path" ] || continue
	svn rm --force "$missing_path"
done < <(svn status "$svn_checkout/trunk" | sed -n 's/^!.......//p')
svn add --force "$svn_checkout/trunk" --parents

if [ "$sync_assets" = true ]; then
	rsync -a --delete --exclude='README.md' --exclude='drafts/' --exclude='.svn' \
		"$root/$assets_directory/" "$svn_checkout/assets/"
	svn add --force "$svn_checkout/assets" --parents
fi

if svn ls "$svn_url/tags/$version" --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD" >/dev/null 2>&1; then
	echo "WordPress.org tag $version already exists; refusing to replace it." >&2
	exit 1
fi

svn status "$svn_checkout"
commit_output=$(svn commit "$svn_checkout" -m "Release $version" --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD")
printf '%s\n' "$commit_output"
committed_revision=$(printf '%s\n' "$commit_output" | sed -nE 's/^Committed revision ([0-9]+)\.$/\1/p')
[[ "$committed_revision" =~ ^[0-9]+$ ]] || {
	echo 'SVN did not report one committed revision; refusing to tag a moving trunk.' >&2
	exit 1
}
svn copy -r "$committed_revision" "$svn_url/trunk" "$svn_url/tags/$version" -m "Tag $version" --non-interactive --no-auth-cache --username "$WORDPRESS_ORG_USERNAME" --password "$WORDPRESS_ORG_PASSWORD"
