#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fixtures="$repo_root/tests/fixtures/release-lifecycle"
repository='RocketsAreNostalgic/ran-ecwid-shop-teaser'
head_ref='release-please--branches--main--components--ran-ecwid-shop-teaser'
head_sha='1111111111111111111111111111111111111111'
bot='github-actions[bot]'
workflow_id=88

ruleset_admitted() {
	jq -e '
		.enforcement == "active"
		and has("bypass_actors")
		and (.bypass_actors | type == "array" and length == 0)
		and has("current_user_can_bypass")
		and .current_user_can_bypass == "never"
		and any(.rules[]; .type == "required_linear_history")
		and any(.rules[]; .type == "pull_request" and (.parameters.allowed_merge_methods | sort) == ["rebase", "squash"])
		and any(.rules[]; .type == "required_status_checks"
			and .parameters.strict_required_status_checks_policy == true
			and ([.parameters.required_status_checks[].context] | index("Quality and release artifact") != null)
			and ([.parameters.required_status_checks[].context] | index("PHP 8.3 / WordPress latest") != null))
	' "$1" >/dev/null
}

ruleset_admitted "$fixtures/ruleset-valid.json"
if ruleset_admitted "$fixtures/ruleset-missing-bypass-actors.json"; then
	echo 'A ruleset with a redacted bypass_actors field was admitted.' >&2
	exit 1
fi
if ruleset_admitted "$fixtures/ruleset-missing-current-user.json"; then
	echo 'A ruleset with a missing current_user_can_bypass field was admitted.' >&2
	exit 1
fi
if ruleset_admitted "$fixtures/ruleset-bypass-actor.json"; then
	echo 'A ruleset with an explicit bypass actor was admitted.' >&2
	exit 1
fi
if ruleset_admitted "$fixtures/ruleset-bypass-capable.json"; then
	echo 'A bypass-capable caller was admitted.' >&2
	exit 1
fi

selected_run=$(
	jq -cer \
		--arg bot "$bot" \
		--arg head_ref "$head_ref" \
		--arg head_repository "$repository" \
		--arg head_sha "$head_sha" \
		--arg lane release-candidate \
		--argjson workflow_id "$workflow_id" \
		'[.workflow_runs[] | select(
			.workflow_id == $workflow_id
			and .path == ".github/workflows/quality.yml"
			and .event == "pull_request"
			and .conclusion == "success"
			and .head_branch == $head_ref
			and .head_repository.full_name == $head_repository
			and .head_sha == $head_sha
			and ($lane != "release-candidate" or .actor.login == $bot)
		)]
		| sort_by(.run_attempt, .id)
		| if length > 0 then last else error("No successful exact Quality PR run exists.") end' \
		"$fixtures/candidate-runs.json"
)
test "$(jq -r '.id' <<< "$selected_run")" = 500
test "$(jq -r '.run_attempt' <<< "$selected_run")" = 2

attempt_admitted() {
	jq -e \
		--arg bot "$bot" \
		--arg head_ref "$head_ref" \
		--arg head_repository "$repository" \
		--arg head_sha "$head_sha" \
		--arg lane release-candidate \
		--argjson attempt 2 \
		--argjson run_id 500 \
		--argjson workflow_id "$workflow_id" \
		'.id == $run_id and .run_attempt == $attempt and .workflow_id == $workflow_id
			and .path == ".github/workflows/quality.yml" and .event == "pull_request"
			and .status == "completed" and .conclusion == "success"
			and .head_branch == $head_ref and .head_repository.full_name == $head_repository
			and .head_sha == $head_sha and .repository.full_name == $head_repository
			and (.triggering_actor.login | type == "string" and length > 0)
			and ($lane != "release-candidate" or .actor.login == $bot)' \
		"$1" >/dev/null
}

attempt_admitted "$fixtures/candidate-attempt-human-retry.json"
if attempt_admitted "$fixtures/candidate-attempt-human-actor.json"; then
	echo 'A candidate Quality run owned by a human actor was admitted.' >&2
	exit 1
fi

published_release_admitted() (
	fixture=$1
	work_directory=$(mktemp -d)
	trap 'rm -rf "$work_directory"' EXIT HUP INT TERM
	version=1.2.3
	commit='1111111111111111111111111111111111111111'
	tag=v1.2.3
	expected=$(printf '%s\n' \
		"ran-ecwid-shop-teaser-${version}.manifest.json" \
		"ran-ecwid-shop-teaser-${version}.zip" \
		"ran-ecwid-shop-teaser-${version}.zip.sha256" \
		| jq -Rsc 'split("\n") | map(select(length > 0)) | sort')

	jq -e --arg commit "$commit" --arg tag "$tag" --argjson expected "$expected" '
		.release.tag_name == $tag
		and .release.draft == false
		and .release.target_commitish == $commit
		and (.release | ((has("immutable") | not) or (.immutable | type == "boolean")))
		and ([.release.assets[].name] | sort) == $expected
	' "$fixture" >/dev/null || exit 1

	while IFS= read -r name; do
		mkdir -p "$work_directory/local" "$work_directory/published"
		jq -er --arg name "$name" '.local_assets[$name]' "$fixture" > "$work_directory/local/$name"
		jq -er --arg name "$name" '.published_assets[$name]' "$fixture" > "$work_directory/published/$name"
		cmp --silent "$work_directory/local/$name" "$work_directory/published/$name" || exit 1
	done < <(jq -r '.release.assets[].name' "$fixture")
)

published_release_admitted "$fixtures/published-release-valid.json"
if published_release_admitted "$fixtures/published-release-extra-asset.json"; then
	echo 'A published release with a stale extra asset was admitted.' >&2
	exit 1
fi
if published_release_admitted "$fixtures/published-release-poisoned.json"; then
	echo 'A published release with poisoned same-name bytes was admitted.' >&2
	exit 1
fi
if published_release_admitted "$fixtures/published-release-wrong-target.json"; then
	echo 'A published release targeting the wrong commit was admitted.' >&2
	exit 1
fi

tag_release_admitted() {
	local fixture=$1
	local object_sha object_type release_target tag tag_object tag_ref
	tag=$(jq -er '.tag' "$fixture")
	tag_ref=$(jq -cer '.tag_ref' "$fixture")
	test "$(jq -er '.ref' <<< "$tag_ref")" = "refs/tags/${tag}" || return 1
	object_type=$(jq -er '.object.type' <<< "$tag_ref")
	object_sha=$(jq -er '.object.sha' <<< "$tag_ref")
	if [[ "$object_type" == tag ]]; then
		tag_object=$(jq -cer --arg sha "$object_sha" '.tag_objects[$sha]' "$fixture")
		test "$(jq -er '.tag' <<< "$tag_object")" = "$tag" || return 1
		object_type=$(jq -er '.object.type' <<< "$tag_object")
		object_sha=$(jq -er '.object.sha' <<< "$tag_object")
	fi
	test "$object_type" = commit || return 1
	release_target=$(jq -er '.release.target_commitish' "$fixture")
	test "$release_target" = "$object_sha" || return 1
}

tag_release_admitted "$fixtures/tag-lightweight.json"
tag_release_admitted "$fixtures/tag-annotated.json"
if tag_release_admitted "$fixtures/tag-shadow.json"; then
	echo 'A same-name branch shadowing a different exact tag commit was admitted.' >&2
	exit 1
fi

printf 'Release lifecycle fixture tests passed.\n'
