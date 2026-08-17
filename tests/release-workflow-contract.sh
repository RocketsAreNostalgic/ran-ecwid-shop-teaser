#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
quality="$repo_root/.github/workflows/quality.yml"
release="$repo_root/.github/workflows/release-please.yml"
deploy="$repo_root/scripts/deploy-wordpress-org.sh"

require() {
	local file=$1
	local text=$2
	grep -Fq -- "$text" "$file" || {
		printf 'Missing workflow contract in %s: %s\n' "$file" "$text" >&2
		exit 1
	}
}

reject() {
	local file=$1
	local text=$2
	if grep -Fq -- "$text" "$file"; then
		printf 'Forbidden workflow contract in %s: %s\n' "$file" "$text" >&2
		exit 1
	fi
}

# These are literal workflow contracts, not shell expressions.
require "$quality" 'pull_request:'
require "$quality" 'workflow_dispatch:'
require "$quality" 'release_pr:'
require "$quality" "format('Quality candidate PR #{0} @ {1}', inputs.release_pr, github.sha)"
reject "$quality" 'push:'
require "$quality" 'pr_json="$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${RAN_DISPATCH_PR}")"'
require "$quality" 'and .head.sha == $sha'
require "$quality" 'test "$GITHUB_REF" = "refs/heads/${pr_head_ref}"'
require "$quality" 'bash scripts/validate-release-candidate.sh "$pr_base_sha" "$pr_head_sha"'
require "$quality" 'git checkout --detach "$pr_head_sha"'
require "$quality" 'source_commit="$pr_head_sha"'
require "$quality" 'schema: "ran-ecwid-shop-teaser-ci-release"'
require "$quality" 'workflowBlob'
require "$quality" 'release-candidate'
require "$quality" 'integration_tests":false'
require "$quality" 'retention-days: 30'
require "$quality" 'name: Quality and release artifact'
require "$quality" 'name: PHP ${{ matrix.php }} / WordPress ${{ matrix.wordpress }}'

require "$release" 'push:'
require "$release" '.enforcement == "active"'
require "$release" 'and has("bypass_actors")'
require "$release" 'and (.bypass_actors | type == "array" and length == 0)'
require "$release" 'and has("current_user_can_bypass")'
require "$release" 'and .current_user_can_bypass == "never"'
reject "$release" '.bypass_actors // []'
require "$release" '(.parameters.allowed_merge_methods | sort) == ["rebase", "squash"]'
require "$release" 'strict_required_status_checks_policy == true'
require "$release" 'pulls?state=closed&base=main&per_page=100'
require "$release" '.merge_commit_sha == $merge'
require "$release" 'runs?head_sha=${head_sha}&status=completed'
require "$release" 'actions/runs/${run_id}/attempts/${run_attempt}'
require "$release" 'startswith("tests/fixtures/release-lifecycle/")'
require "$release" 'and ($lane != "release-candidate" or .actor.login == $bot)'
require "$release" 'and (.triggering_actor.login | type == "string" and length > 0)'
require "$release" '($run_event == "workflow_dispatch" and .display_title == $dispatch_title)'
require "$release" 'printf '\''artifact-name=ran-ecwid-shop-teaser-ci-release-%s-%s\n'\'' "$run_id" "$run_attempt"'
require "$release" 'run-id: ${{ steps.lifecycle.outputs.run-id }}'
require "$release" '.sourceTree == $main_tree and .testedTree == $main_tree'
require "$release" '($lane == "release-candidate" and .sourceCommit == $head_sha'
require "$release" 'refs/heads/${RAN_HEAD_REF}'
require "$release" 'refs/pull/${RAN_PR_NUMBER}/head'
require "$release" 'bash scripts/validate-release-candidate.sh "$RAN_BASE_SHA" "$release_head"'
require "$release" '--target "$RAN_RELEASE_COMMIT"'
require "$release" '--verify-tag --draft --target "$RAN_RELEASE_COMMIT"'
require "$release" 'skip-github-release: true'
require "$release" 'id: release_please'
require "$release" 'RAN_RELEASE_PR: ${{ steps.release_please.outputs.pr }}'
require "$release" 'RAN_RELEASE_PRS_CREATED: ${{ steps.release_please.outputs.prs_created }}'
require "$release" 'name: Recover and dispatch exact secretless candidate Quality'
require "$release" 'pulls?state=open&base=main&per_page=100'
require "$release" 'test "$candidate_count" == 1'
require "$release" 'and .base.ref == "main" and .base.sha == $sha'
require "$release" 'and .author.login == $bot'
require "$release" 'and .committer.login == $committer'
require "$release" 'and .commit.verification.verified == true'
require "$release" 'and .commit.verification.reason == "valid"'
require "$release" 'and (.parents | length) == 1'
require "$release" 'and .parents[0].sha == $base_sha'
require "$release" 'bash scripts/validate-release-candidate.sh "$base_sha" "$head_sha"'
require "$release" 'runs?event=workflow_dispatch&head_sha=${head_sha}&per_page=100'
require "$release" 'and .display_title == $dispatch_title'
require "$release" '(.status == "completed" and .conclusion == "success")'
require "$release" 'or (.status == "requested" or .status == "queued" or .status == "pending"'
reject "$release" "if: steps.release_please.outputs.prs_created == 'true'"
require "$release" 'actions/workflows/quality.yml/dispatches'
require "$release" '{ref: $ref, inputs: {release_pr: $release_pr}}'
require "$release" 'cmp --silent "dist/${name}" "published-dist/${name}"'
require "$release" 'cmp --silent "dist/${name}" "prepublish-dist/${name}"'
require "$release" '.tag_name == $tag and .draft == true and .target_commitish == $commit'
require "$release" 'git/ref/tags/${TAG_NAME}'
require "$release" 'git/tags/${release_commit}'
require "$release" '.target_commitish == $commit'
require "$release" 'ref: ${{ steps.resolve.outputs.release-commit }}'
require "$release" 'name: Build verified release assets without a write token'
require "$release" 'name: Publish isolated manual release assets'
require "$release" 'needs.publish-manual-release.result == '\''success'\'''
require "$release" 'ref: ${{ env.RELEASE_COMMIT }}'
require "$release" 'for path in composer.json composer.lock package.json pnpm-lock.yaml'
require "$release" "printf 'source-commit=%s\\n' \"\$source_commit\""
require "$release" "printf 'source-tree=%s\\n'"
require "$release" "jq -er '.sourceTree'"
require "$release" 'test "$SOURCE_TREE" = "$RELEASE_TREE"'
require "$release" 'git/commits/${SOURCE_COMMIT}'
require "$release" '"$SOURCE_COMMIT" "${options[@]}"'
require "$deploy" 'SOURCE_COMMIT="${4:?The proven source commit is required.}"'
require "$deploy" "\"\$(jq -er '.commit' \"\${MANIFEST_PATH}\")\" != \"\${SOURCE_COMMIT}\""
reject "$deploy" 'git -C "${PLUGIN_ROOT}" rev-parse HEAD'
reject "$release" 'RAN_QUALITY_COMMIT}^2'
reject "$release" 'rev-list --parents'
reject "$release" 'workflow_run:'

manual_build_section=$(sed -n '/^    package-release:/,/^    publish-manual-release:/p' "$release")
grep -Fq 'contents: read' <<< "$manual_build_section"
if grep -Fq 'contents: write' <<< "$manual_build_section"; then
	echo 'Manual build job exposes a contents:write token.' >&2
	exit 1
fi

manual_publish_section=$(sed -n '/^    publish-manual-release:/,/^    deploy-wordpress-org:/p' "$release")
grep -Fq 'contents: write' <<< "$manual_publish_section"
test "$(grep -Fc 'git/ref/tags/${TAG_NAME}' <<< "$manual_publish_section")" -ge 2
test "$(grep -Fc 'and ([.assets[].name] | sort) == $expected' <<< "$manual_publish_section")" -ge 1
grep -Fq 'and ($actual - $expected | length == 0)' <<< "$manual_publish_section"
grep -Fq 'and ((.immutable // false) == false or ($actual | sort) == $expected)' <<< "$manual_publish_section"
test "$(grep -Fc 'test "$tag_commit" = "$RELEASE_COMMIT"' <<< "$manual_publish_section")" -ge 2
for forbidden in 'actions/checkout@' 'bash scripts/' 'pnpm ' 'composer '; do
	if grep -Fq "$forbidden" <<< "$manual_publish_section"; then
		printf 'Manual publish job executes ref-controlled code: %s\n' "$forbidden" >&2
		exit 1
	fi
done

printf 'Release workflow contract tests passed.\n'
