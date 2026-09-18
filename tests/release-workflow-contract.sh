#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
quality="${repo_root}/.github/workflows/quality.yml"
publisher="${repo_root}/.github/workflows/release-publisher.yml"
legacy_publisher="${repo_root}/.github/workflows/release-please.yml"
reconciliation="${repo_root}/.github/workflows/reconcile-v1.2.3.yml"

require() {
	local file=$1
	local text=$2
	grep -Fq -- "$text" "$file" || {
		printf 'Missing release workflow contract in %s: %s\n' "$file" "$text" >&2
		exit 1
	}
}

reject() {
	local file=$1
	local text=$2
	if grep -Fq -- "$text" "$file"; then
		printf 'Forbidden release workflow contract in %s: %s\n' "$file" "$text" >&2
		exit 1
	fi
}

test ! -e "$legacy_publisher"
test ! -e "$reconciliation"

require "$quality" 'pull_request:'
require "$quality" 'push:'
require "$quality" '- main'
require "$quality" 'workflow_dispatch:'
require "$quality" 'release_pr:'
require "$quality" 'candidate_sha:'
require "$quality" "format('Quality candidate PR #{0} {1} @ trusted main {2}', inputs.release_pr, inputs.candidate_sha, github.sha)"
require "$quality" 'name: quality'
require "$quality" 'if: ${{ always() }}'
require "$quality" 'Authenticate canonical Release Please candidate'
require "$quality" 'RAN_CANDIDATE_SHA: ${{ inputs.candidate_sha }}'
require "$quality" 'test "$GITHUB_ACTOR" = '\''github-actions[bot]'\'''
require "$quality" "test \"$GITHUB_REF\" = 'refs/heads/main'"
require "$quality" '.draft == true'
require "$quality" '.base.sha == $base'
require "$quality" '.head.sha == $candidate'
require "$quality" '.commit.verification.verified == true'
require "$quality" '.commit.verification.reason == "valid"'
require "$quality" '.parents[0].sha == $base'
require "$quality" 'bash scripts/validate-release-candidate.sh "$pr_base_sha" "$pr_head_sha"'
require "$quality" 'git checkout --detach "$pr_head_sha"'
require "$quality" 'bash scripts/create-release-assets.sh "v${version}"'
require "$quality" 'schemaVersion: 3'
require "$quality" 'Upload exact release evidence'
require "$quality" "printf 'name=ran-ecwid-shop-teaser-ci-release-%s\\n'"
require "$quality" 'overwrite: true'
require "$quality" '.run.attempt >= 1'
require "$quality" '4a464898bf96f9d5e19e9f04957a702bf9bdc191/templates/install-wp-tests.sh'

require "$publisher" 'workflow_run:'
require "$publisher" 'workflows: [Quality]'
require "$publisher" 'types: [completed]'
require "$publisher" 'branches: [main]'
require "$publisher" "github.event.workflow_run.event == 'push'"
require "$publisher" "github.event.workflow_run.conclusion == 'success'"
require "$publisher" "github.event.workflow_run.head_branch == 'main'"
require "$publisher" 'github.event.workflow_run.head_repository.id == github.repository_id'
require "$publisher" 'github.event.workflow_run.head_repository.full_name == github.repository'
require "$publisher" 'actions/runs/${RAN_QUALITY_RUN_ID}'
require "$publisher" 'artifact-name=ran-ecwid-shop-teaser-ci-release-%s'
require "$publisher" "printf 'run-id=%s\\n'"
require "$publisher" '.path == ".github/workflows/quality.yml"'
require "$publisher" '.head_sha == $commit'
require "$publisher" 'ref: ${{ steps.quality.outputs.commit }}'
require "$publisher" 'persist-credentials: false'

require "$publisher" 'Admit publisher for exact reviewed merge'
require "$publisher" 'Expected exactly one merged PR for the qualified main commit.'
reject "$publisher" 'and .head.repo.full_name == $repository
                                  and .merge_commit_sha == $commit'
require "$publisher" '.github/workflows/quality.yml'
require "$publisher" '.github/workflows/release-publisher.yml'
require "$publisher" 'tests/release-workflow-contract.sh'
require "$publisher" 'tests/release-publication-contract.sh'
require "$publisher" 'scripts/validate-release-candidate.sh'
require "$publisher" 'scripts/create-release-assets.sh'
require "$publisher" 'tools/build-release.php'
require "$publisher" 'wordpress-org/deployment.json'
require "$publisher" 'release-please-config.json'
require "$publisher" "printf 'admitted=false\\n'"
require "$publisher" "printf 'admitted=true\\n'"
require "$publisher" 'Revalidate exact current main'
require "$publisher" 'git/ref/heads/main'
require "$publisher" "printf 'current=false\\n'"
require "$publisher" "printf 'current=true\\n'"
require "$publisher" "steps.current_main.outputs.current == 'true'"

require "$publisher" 'googleapis/release-please-action@'
require "$publisher" "if: steps.admission.outputs.admitted == 'true'"
require "$publisher" "expected_head='release-please--branches--main--components--ran-ecwid-shop-teaser'"
require "$publisher" 'runs?head_sha=${base_sha}&per_page=100'
require "$publisher" 'and .head_branch == "main"'
require "$publisher" '{ref: $ref, inputs: {release_pr: $release_pr, candidate_sha: $candidate_sha}}'
require "$publisher" '--arg ref "main"'
require "$publisher" '.user.login == $bot'
require "$publisher" '.head.repo.full_name == $repository'
require "$publisher" 'actions/workflows/quality.yml/dispatches'
require "$publisher" '.event == "workflow_dispatch"'
require "$publisher" '.display_title == $dispatch_title'
require "$publisher" '.actor.login == $bot'
require "$publisher" 'RAN_QUALITY_COMMIT: ${{ steps.quality.outputs.commit }}'
require "$publisher" 'test "$base_sha" = "$RAN_QUALITY_COMMIT"'
require "$publisher" '.commit.verification.verified == true'
require "$publisher" 'git fetch --no-tags origin'
require "$publisher" 'bash scripts/validate-release-candidate.sh "$base_sha" "$head_sha"'
require "$publisher" '{ref: $ref, inputs: {release_pr: $release_pr}}'

require "$publisher" 'Resolve exact release for the qualified commit'
require "$publisher" 'gh release view "$tag_name" --repo "$GITHUB_REPOSITORY" --json databaseId'
require "$publisher" 'releases/${release_id}'
require "$publisher" "printf 'draft=%s\\n'"
require "$publisher" "printf 'release-id=%s\\n'"
require "$publisher" 'RAN_RELEASE_DRAFT: ${{ steps.release_state.outputs.draft }}'
require "$publisher" 'RAN_RELEASE_ID: ${{ steps.release_state.outputs.release-id }}'
require "$publisher" "jq -nc '{draft:false}'"
require "$publisher" 'releases/${RAN_RELEASE_ID}'
require "$publisher" 'RAN_RELEASE_CREATED: ${{ steps.release.outputs.release_created }}'
require "$publisher" 'ready=false'
require "$publisher" 'ready=true'
require "$publisher" "if: steps.release_state.outputs.ready == 'true'"
require "$publisher" "if: steps.admission.outputs.admitted == 'true'"
require "$publisher" 'Download exact qualified release assets'
require "$publisher" 'run-id: ${{ steps.quality.outputs.run-id }}'
require "$publisher" 'schemaVersion == 3'
require "$publisher" 'releases/assets/${existing_id}'
require "$publisher" 'uploads.github.com/repos/${GITHUB_REPOSITORY}/releases/${RAN_RELEASE_ID}/assets?name=${name}'
require "$publisher" 'git/ref/tags/${tag_name}'
require "$publisher" '.target_commitish == $commit'
require "$publisher" 'remote_digests='
require "$publisher" 'test "$remote_digests" = "$local_digests"'
require "$publisher" 'final_tag_ref='
require "$publisher" 'final_tag_commit='
require "$publisher" 'test "$final_tag_commit" = "$RAN_QUALITY_COMMIT"'

reject "$publisher" 'rules/branches/main'
reject "$publisher" '/rulesets'
reject "$publisher" 'Manually rebuild an existing release'
reject "$publisher" 'Publish isolated manual release assets'
reject "$publisher" 'Deploy to WordPress.org'
reject "$publisher" 'reconcile-v1.2.3'

if grep -Eq '^[[:space:]]+workflow_dispatch:' "$publisher"; then
	echo 'Release publisher must not expose a manual dispatch trigger.' >&2
	exit 1
fi

printf 'Simplified release workflow contract passed.\n'

release_config="$repo_root/release-please-config.json"
jq -e '."packages".".".draft == true
  and ."packages"."."."force-tag-creation" == true
  and ."packages"."."."draft-pull-request" == true' "$release_config" >/dev/null

reject "$publisher" 'gh release upload "$RAN_TAG_NAME"'
