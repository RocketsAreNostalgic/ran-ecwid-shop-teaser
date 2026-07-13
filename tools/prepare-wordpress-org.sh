#!/usr/bin/env sh
#
# Prepare a local WordPress.org SVN import tree without contacting WordPress.org.
#
set -eu

plugin_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
slug=ran-ecwid-shop-teaser
version=$(sed -n 's/^ \* Version: \(.*\)$/\1/p' "$plugin_dir/$slug.php" | head -n 1)
archive="$plugin_dir/dist/$slug-$version.zip"
svn_root="$plugin_dir/wordpress-org/svn"

php "$plugin_dir/tools/build-release.php"

if [ -e "$svn_root/trunk" ] || [ -e "$svn_root/tags/$version" ] || [ -e "$svn_root/$slug" ]; then
	echo "Refusing to overwrite an existing WordPress.org staging tree." >&2
	exit 1
fi

mkdir -p "$svn_root/tags"
unzip -q "$archive" -d "$svn_root"
mv "$svn_root/$slug" "$svn_root/trunk"
cp -R "$svn_root/trunk" "$svn_root/tags/$version"

cat <<EOF
Prepared local WordPress.org SVN content:
  $svn_root/trunk
  $svn_root/tags/$version

Copy approved files from wordpress-org-assets/ into the remote SVN assets/ directory.
Review the generated tree, directory assets, contributor account, trademark
status, and third-party service disclosures before any SVN commit.
EOF
