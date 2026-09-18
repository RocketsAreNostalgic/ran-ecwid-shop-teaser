#!/usr/bin/env bash
set -euo pipefail

expected_commit='1111111111111111111111111111111111111111'
expected_tag='v1.2.4'
expected_names='["ran-ecwid-shop-teaser-1.2.4.manifest.json","ran-ecwid-shop-teaser-1.2.4.zip","ran-ecwid-shop-teaser-1.2.4.zip.sha256"]'
expected_digests='[
  {"name":"ran-ecwid-shop-teaser-1.2.4.manifest.json","digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  {"name":"ran-ecwid-shop-teaser-1.2.4.zip","digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
  {"name":"ran-ecwid-shop-teaser-1.2.4.zip.sha256","digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}
]'

resolve_tag_commit() {
	local fixture=$1
	local object_type object_sha tag_object peel_count=0
	object_type=$(jq -er '.tag_ref.object.type' <<< "$fixture")
	object_sha=$(jq -er '.tag_ref.object.sha' <<< "$fixture")
	while [[ "$object_type" == tag ]]; do
		((peel_count += 1))
		test "$peel_count" -le 8
		tag_object=$(jq -cer --arg sha "$object_sha" '.tag_objects[$sha]' <<< "$fixture")
		if [[ "$peel_count" -eq 1 ]]; then
			test "$(jq -er '.tag' <<< "$tag_object")" = "$expected_tag"
		fi
		object_type=$(jq -er '.object.type' <<< "$tag_object")
		object_sha=$(jq -er '.object.sha' <<< "$tag_object")
	done
	test "$object_type" = commit
	printf '%s\n' "$object_sha"
}

lightweight=$(jq -nc --arg commit "$expected_commit" 	'{tag_ref:{object:{type:"commit",sha:$commit}},tag_objects:{}}')
test "$(resolve_tag_commit "$lightweight")" = "$expected_commit"

annotated=$(jq -nc --arg commit "$expected_commit" --arg tag "$expected_tag" '
	{
	  tag_ref:{object:{type:"tag",sha:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
	  tag_objects:{
	    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa":{
	      tag:$tag,
	      object:{type:"commit",sha:$commit}
	    }
	  }
	}')
test "$(resolve_tag_commit "$annotated")" = "$expected_commit"

wrong_target=$(jq -nc 	'{tag_ref:{object:{type:"commit",sha:"2222222222222222222222222222222222222222"}},tag_objects:{}}')
if [[ "$(resolve_tag_commit "$wrong_target")" == "$expected_commit" ]]; then
	echo 'A tag resolving to the wrong commit was admitted.' >&2
	exit 1
fi

release_admitted() {
	local release=$1
	jq -e 		--arg commit "$expected_commit" 		--arg tag "$expected_tag" 		--argjson expected_names "$expected_names" 		--argjson expected_digests "$expected_digests" '
		.tag_name == $tag
		and .target_commitish == $commit
		and .draft == false
		and .prerelease == false
		and ([.assets[].name] | sort) == $expected_names
		and ([.assets[] | {name, digest}] | sort_by(.name)) == $expected_digests
	' <<< "$release" >/dev/null
}

valid_release=$(jq -nc 	--arg commit "$expected_commit" 	--arg tag "$expected_tag" 	--argjson digests "$expected_digests" 	'{tag_name:$tag,target_commitish:$commit,draft:false,prerelease:false,immutable:false,assets:$digests}')
release_admitted "$valid_release"

missing_asset=$(jq -c '.assets = .assets[0:2]' <<< "$valid_release")
if release_admitted "$missing_asset"; then
	echo 'A release missing an expected asset was admitted.' >&2
	exit 1
fi

extra_asset=$(jq -c '.assets += [{"name":"unexpected.txt","digest":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}]' <<< "$valid_release")
if release_admitted "$extra_asset"; then
	echo 'A release with an extra asset was admitted.' >&2
	exit 1
fi

poisoned=$(jq -c '(.assets[] | select(.name | endswith(".zip")) | .digest) = "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"' <<< "$valid_release")
if release_admitted "$poisoned"; then
	echo 'A release with a poisoned same-name asset digest was admitted.' >&2
	exit 1
fi

wrong_release_target=$(jq -c '.target_commitish = "3333333333333333333333333333333333333333"' <<< "$valid_release")
if release_admitted "$wrong_release_target"; then
	echo 'A release targeting the wrong commit was admitted.' >&2
	exit 1
fi

printf 'Focused release publication behavior passed.\n'

draft_release=$(jq -nc \
	--arg commit "$expected_commit" \
	--arg tag "$expected_tag" \
	--argjson digests "$expected_digests" \
	'{id:4242,tag_name:$tag,target_commitish:$commit,draft:true,prerelease:false,immutable:false,assets:$digests}')
jq -e --arg commit "$expected_commit" --arg tag "$expected_tag" \
	'.tag_name == $tag and .target_commitish == $commit and .draft == true and .prerelease == false' \
	<<< "$draft_release" >/dev/null

immutable_complete=$(jq -c '.draft = false | .immutable = true' <<< "$valid_release")
release_admitted "$immutable_complete"
