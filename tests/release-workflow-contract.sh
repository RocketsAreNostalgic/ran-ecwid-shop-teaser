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
require "$quality" 'name: quality'
require "$quality" 'if: ${{ always() }}'
require "$quality" 'bash scripts/create-release-assets.sh "v${version}"'
require "$quality" 'schemaVersion: 3'
require "$quality" 'Upload exact release evidence'
reject "$quality" 'release-candidate'
reject "$quality" 'validate-release-candidate.sh'
reject "$quality" 'release_pr:'

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
require "$publisher" 'artifact-name=ran-ecwid-shop-teaser-ci-release-%s-%s'
require "$publisher" "printf 'run-attempt=%s\\n'"
require "$publisher" "printf 'run-id=%s\\n'"
require "$publisher" '.path == ".github/workflows/quality.yml"'
require "$publisher" '.head_sha == $commit'
require "$publisher" 'ref: ${{ steps.quality.outputs.commit }}'
require "$publisher" 'persist-credentials: false'
require "$publisher" 'googleapis/release-please-action@'
require "$publisher" "expected_head='release-please--branches--main--components--ran-ecwid-shop-teaser'"
require "$publisher" '.user.login == $bot'
require "$publisher" '.head.repo.full_name == $repository'
require "$publisher" 'actions/workflows/quality.yml/dispatches'
require "$publisher" '{ref: $ref}'
require "$publisher" 'Download exact qualified release assets'
require "$publisher" 'run-id: ${{ steps.quality.outputs.run-id }}'
require "$publisher" 'schemaVersion == 3'
require "$publisher" 'gh release upload "$RAN_TAG_NAME"'
require "$publisher" 'git/ref/tags/${RAN_TAG_NAME}'
require "$publisher" '.target_commitish == $commit'
require "$publisher" 'remote_digests='
require "$publisher" 'test "$remote_digests" = "$local_digests"'

reject "$publisher" 'rules/branches/main'
reject "$publisher" '/rulesets'
reject "$publisher" 'Manually rebuild an existing release'
reject "$publisher" 'Publish isolated manual release assets'
reject "$publisher" 'Deploy to WordPress.org'
reject "$publisher" 'reconcile-v1.2.3'
reject "$publisher" 'validate-release-candidate.sh'

if grep -Eq '^[[:space:]]+workflow_dispatch:' "$publisher"; then
	echo 'Release publisher must not expose a manual dispatch trigger.' >&2
	exit 1
fi

printf 'Simplified release workflow contract passed.\n'
