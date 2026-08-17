#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fixtures="$repo_root/tests/fixtures/release-lifecycle"
repository='RocketsAreNostalgic/ran-ecwid-shop-teaser'
head_ref='release-please--branches--main--components--ran-ecwid-shop-teaser'
head_sha='1111111111111111111111111111111111111111'
base_sha='2222222222222222222222222222222222222222'
pr_number=11
dispatch_title="Quality candidate PR #${pr_number} @ ${head_sha}"
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

candidate_dispatch_pr_admitted() {
	jq -e \
		--arg bot "$bot" \
		--arg head "$head_ref" \
		--arg repository "$repository" \
		--arg sha "$head_sha" \
		'.state == "open" and .user.login == $bot and .base.ref == "main"
			and .head.ref == $head and .head.repo.full_name == $repository
			and .head.sha == $sha' "$1" >/dev/null
}

candidate_dispatch_pr_admitted "$fixtures/candidate-dispatch-pr.json"
if jq '(.head.sha = "3333333333333333333333333333333333333333")' "$fixtures/candidate-dispatch-pr.json" \
	| candidate_dispatch_pr_admitted /dev/stdin; then
	echo 'A dispatch for a stale Release Please PR head was admitted.' >&2
	exit 1
fi

recoverable_candidate_admitted() {
	jq -e \
		--arg base_sha "$base_sha" \
		--arg bot "$bot" \
		--arg committer web-flow \
		--arg head_ref "$head_ref" \
		--arg head_sha "$head_sha" \
		--arg repository "$repository" \
		'.pr.state == "open"
			and .pr.user.login == $bot
			and .pr.base.ref == "main"
			and .pr.base.sha == $base_sha
			and .pr.head.ref == $head_ref
			and .pr.head.repo.full_name == $repository
			and .pr.head.sha == $head_sha
			and .branchSha == $head_sha
			and .commit.sha == $head_sha
			and .commit.author.login == $bot
			and .commit.committer.login == $committer
			and .commit.commit.verification.verified == true
			and .commit.commit.verification.reason == "valid"
			and (.commit.parents | length) == 1
			and .commit.parents[0].sha == $base_sha' "$1" >/dev/null
}

recoverable_candidate_admitted "$fixtures/recovery-candidate-valid.json"
for rejected in \
	"$fixtures/recovery-candidate-human.json" \
	"$fixtures/recovery-candidate-stale.json" \
	"$fixtures/recovery-candidate-moved-head.json"; do
	if recoverable_candidate_admitted "$rejected"; then
		printf 'An invalid durable candidate was admitted: %s\n' "$rejected" >&2
		exit 1
	fi
done

action_output_admitted() {
	local fixture=$1
	local prs_created=$2
	local action_output=$3
	local number
	number=$(jq -er '.pr.number' "$fixture")
	if [[ "$prs_created" == true ]]; then
		jq -e \
			--arg base main \
			--arg head "$head_ref" \
			--argjson number "$number" \
			'.number == $number and .baseBranchName == $base and .headBranchName == $head' \
			<<< "$action_output" >/dev/null
	else
		test -z "$action_output"
	fi
}

action_output_admitted "$fixtures/recovery-candidate-valid.json" false ''
matching_action_output=$(jq -nc --arg head "$head_ref" '{number: 11, baseBranchName: "main", headBranchName: $head}')
action_output_admitted "$fixtures/recovery-candidate-valid.json" true "$matching_action_output"
if action_output_admitted "$fixtures/recovery-candidate-valid.json" true '{"number":12,"baseBranchName":"main","headBranchName":"moved"}'; then
	echo 'A mismatched Release Please action output was admitted.' >&2
	exit 1
fi

dispatch_suppressed() {
	local state=$1
	jq -e \
		--arg bot "$bot" \
		--arg dispatch_title "$dispatch_title" \
		--arg head_ref "$head_ref" \
		--arg head_repository "$repository" \
		--arg head_sha "$head_sha" \
		--arg state "$state" \
		--argjson workflow_id "$workflow_id" \
		'any(.[$state].workflow_runs[];
			.workflow_id == $workflow_id
			and .path == ".github/workflows/quality.yml"
			and .event == "workflow_dispatch"
			and .display_title == $dispatch_title
			and .head_branch == $head_ref
			and .head_repository.full_name == $head_repository
			and .head_sha == $head_sha
			and .actor.login == $bot
			and (
				(.status == "completed" and .conclusion == "success")
				or (.status == "requested" or .status == "queued" or .status == "pending"
					or .status == "waiting" or .status == "in_progress")
			)
		)' "$fixtures/candidate-dispatch-recovery-runs.json" >/dev/null
}

if dispatch_suppressed failedCancelled; then
	echo 'Failed or cancelled candidate dispatches suppressed a recovery retry.' >&2
	exit 1
fi
dispatch_suppressed active
dispatch_suppressed successful
if dispatch_suppressed wrongIdentity; then
	echo 'A workflow dispatch without the durable candidate identity suppressed recovery.' >&2
	exit 1
fi

selected_run=$(
	jq -cer \
		--arg bot "$bot" \
		--arg head_ref "$head_ref" \
		--arg head_repository "$repository" \
			--arg head_sha "$head_sha" \
			--arg lane release-candidate \
			--arg dispatch_title "$dispatch_title" \
		--argjson workflow_id "$workflow_id" \
		'[.workflow_runs[] | select(
			.workflow_id == $workflow_id
			and .path == ".github/workflows/quality.yml"
				and (($lane == "release-candidate" and (.event == "pull_request"
						or (.event == "workflow_dispatch" and .display_title == $dispatch_title)))
					or ($lane == "full" and .event == "pull_request"))
			and .conclusion == "success"
			and .head_branch == $head_ref
			and .head_repository.full_name == $head_repository
			and .head_sha == $head_sha
			and ($lane != "release-candidate" or .actor.login == $bot)
		)]
			| sort_by(.id, .run_attempt)
		| if length > 0 then last else error("No successful exact Quality PR run exists.") end' \
		"$fixtures/candidate-runs.json"
)
test "$(jq -r '.id' <<< "$selected_run")" = 504
test "$(jq -r '.run_attempt' <<< "$selected_run")" = 1
test "$(jq -r '.event' <<< "$selected_run")" = workflow_dispatch

attempt_admitted() {
	local fixture=$1
	local run_event=$2
	local run_id=$3
	local run_attempt=$4
	jq -e \
		--arg bot "$bot" \
		--arg head_ref "$head_ref" \
		--arg head_repository "$repository" \
		--arg head_sha "$head_sha" \
		--arg lane release-candidate \
		--arg dispatch_title "$dispatch_title" \
		--arg run_event "$run_event" \
		--argjson attempt "$run_attempt" \
		--argjson run_id "$run_id" \
		--argjson workflow_id "$workflow_id" \
		'.id == $run_id and .run_attempt == $attempt and .workflow_id == $workflow_id
			and .path == ".github/workflows/quality.yml" and .event == $run_event
			and (($lane == "release-candidate" and ($run_event == "pull_request"
					or ($run_event == "workflow_dispatch" and .display_title == $dispatch_title)))
				or ($lane == "full" and $run_event == "pull_request"))
			and .status == "completed" and .conclusion == "success"
			and .head_branch == $head_ref and .head_repository.full_name == $head_repository
			and .head_sha == $head_sha and .repository.full_name == $head_repository
			and (.triggering_actor.login | type == "string" and length > 0)
			and ($lane != "release-candidate" or .actor.login == $bot)' \
		"$fixture" >/dev/null
}

attempt_admitted "$fixtures/candidate-attempt-human-retry.json" pull_request 500 2
attempt_admitted "$fixtures/candidate-attempt-dispatch.json" workflow_dispatch 504 1
if attempt_admitted "$fixtures/candidate-attempt-human-actor.json" pull_request 500 2; then
	echo 'A candidate Quality run owned by a human actor was admitted.' >&2
	exit 1
fi

dependency_contract_changed() {
	local files=$1
	local path
	for path in composer.json composer.lock package.json pnpm-lock.yaml; do
		if jq -e --arg path "$path" 'any(.filename == $path)' "$files" >/dev/null; then
			return 0
		fi
	done
	return 1
}

dependency_contract_changed "$fixtures/pr-files-dependency-locks.json"

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
if published_release_admitted "$fixtures/published-release-missing-asset.json"; then
	echo 'An incomplete published release was admitted as final.' >&2
	exit 1
fi
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

manual_release_repairable() (
	fixture=$1
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
		and ([.release.assets[].name] as $actual
			| ($actual | unique | length) == ($actual | length)
			and ($actual - $expected | length == 0)
			and ((.release.immutable // false) == false or ($actual | sort) == $expected))
	' "$fixture" >/dev/null || exit 1

	if [[ "$(jq -r '.release.immutable // false' "$fixture")" == true ]]; then
		while IFS= read -r name; do
			test "$(jq -er --arg name "$name" '.local_assets[$name]' "$fixture")" = \
				"$(jq -er --arg name "$name" '.published_assets[$name]' "$fixture")" || exit 1
		done < <(jq -r '.release.assets[].name' "$fixture")
	fi
)

manual_release_repairable "$fixtures/published-release-valid.json"
manual_release_repairable "$fixtures/published-release-missing-asset.json"
manual_release_repairable "$fixtures/published-release-poisoned.json"
if manual_release_repairable "$fixtures/published-release-extra-asset.json"; then
	echo 'A mutable release with a stale extra asset was considered repairable.' >&2
	exit 1
fi
if manual_release_repairable "$fixtures/published-release-immutable-missing-asset.json"; then
	echo 'An incomplete immutable release was considered repairable.' >&2
	exit 1
fi
if manual_release_repairable "$fixtures/published-release-immutable-poisoned.json"; then
	echo 'An immutable release with mismatched bytes was considered repairable.' >&2
	exit 1
fi

deployment_provenance_admitted() {
	jq -e '
		(.sourceCommit | test("^[0-9a-f]{40}$"))
		and (.releaseCommit | test("^[0-9a-f]{40}$"))
		and .sourceTree == .releaseTree
		and .manifest.commit == .sourceCommit
	' "$1" >/dev/null
}

deployment_provenance_admitted "$fixtures/deployment-provenance.json"
if jq '(.manifest.commit = .releaseCommit)' "$fixtures/deployment-provenance.json" \
	| deployment_provenance_admitted /dev/stdin; then
	echo 'A squash release manifest bound to the release commit instead of the source commit was admitted.' >&2
	exit 1
fi
if jq '(.releaseTree = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")' "$fixtures/deployment-provenance.json" \
	| deployment_provenance_admitted /dev/stdin; then
	echo 'Different source and release trees were admitted for deployment.' >&2
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
