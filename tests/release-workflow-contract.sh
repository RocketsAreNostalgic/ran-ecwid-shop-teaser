#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
quality="$repo_root/.github/workflows/quality.yml"
release="$repo_root/.github/workflows/release-please.yml"

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
reject "$quality" 'push:'
require "$quality" 'bash scripts/validate-release-candidate.sh "$RAN_PR_BASE_SHA" "$RAN_PR_HEAD_SHA"'
require "$quality" 'git checkout --detach "$RAN_PR_HEAD_SHA"'
require "$quality" 'source_commit="$RAN_PR_HEAD_SHA"'
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
require "$release" 'runs?event=pull_request&head_sha=${head_sha}&status=completed'
require "$release" 'actions/runs/${run_id}/attempts/${run_attempt}'
require "$release" 'startswith("tests/fixtures/release-lifecycle/")'
require "$release" 'and ($lane != "release-candidate" or .actor.login == $bot)'
require "$release" 'and (.triggering_actor.login | type == "string" and length > 0)'
require "$release" 'printf '\''artifact-name=ran-ecwid-shop-teaser-ci-release-%s-%s\n'\'' "$run_id" "$run_attempt"'
require "$release" 'run-id: ${{ steps.lifecycle.outputs.run-id }}'
require "$release" '.sourceTree == $main_tree and .testedTree == $main_tree'
require "$release" '($lane == "release-candidate" and .sourceCommit == $head_sha'
require "$release" 'refs/pull/${RAN_PR_NUMBER}/head'
require "$release" 'bash scripts/validate-release-candidate.sh "$RAN_BASE_SHA" "$release_head"'
require "$release" '--target "$RAN_RELEASE_COMMIT"'
require "$release" '--verify-tag --draft --target "$RAN_RELEASE_COMMIT"'
require "$release" 'skip-github-release: true'
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
test "$(grep -Fc 'and ([.assets[].name] | sort) == $expected' <<< "$manual_publish_section")" -ge 2
test "$(grep -Fc 'test "$tag_commit" = "$RELEASE_COMMIT"' <<< "$manual_publish_section")" -ge 2
for forbidden in 'actions/checkout@' 'bash scripts/' 'pnpm ' 'composer '; do
	if grep -Fq "$forbidden" <<< "$manual_publish_section"; then
		printf 'Manual publish job executes ref-controlled code: %s\n' "$forbidden" >&2
		exit 1
	fi
done

printf 'Release workflow contract tests passed.\n'
