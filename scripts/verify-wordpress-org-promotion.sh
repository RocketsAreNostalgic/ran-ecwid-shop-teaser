#!/usr/bin/env bash
# Read-only admission for an optional WordPress.org deployment.
set -euo pipefail

: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_OUTPUT:?}"
: "${RAN_ADMITTED_SHA:?}"
: "${RAN_PROVIDER_RUN_ID:?}"
: "${RAN_PROVIDER_ATTEMPT:?}"
: "${RAN_RELEASE_TAG:?}"

[[ "$RAN_ADMITTED_SHA" =~ ^[0-9a-f]{40}$ ]]
[[ "$RAN_PROVIDER_RUN_ID" =~ ^[1-9][0-9]*$ ]]
[[ "$RAN_PROVIDER_ATTEMPT" =~ ^[1-9][0-9]*$ ]]
[[ "$RAN_RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]

provider="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${RAN_PROVIDER_RUN_ID}/attempts/${RAN_PROVIDER_ATTEMPT}")"
jq -e --arg sha "$RAN_ADMITTED_SHA" --arg repo "$GITHUB_REPOSITORY" --argjson id "$RAN_PROVIDER_RUN_ID" --argjson attempt "$RAN_PROVIDER_ATTEMPT" '
  .id == $id and .run_attempt == $attempt
  and .event == "workflow_run" and .path == ".github/workflows/release-please.yml"
  and .head_sha == $sha and .head_branch == "main"
  and .head_repository.full_name == $repo
  and .status == "completed" and .conclusion == "success"
' <<< "$provider" >/dev/null

jobs="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${RAN_PROVIDER_RUN_ID}/attempts/${RAN_PROVIDER_ATTEMPT}/jobs?per_page=100")"
job_ids="$(jq -c '[.jobs[] | select(
  .conclusion == "success"
  and any(.steps[]; .name == "Download exact Quality artifact" and .conclusion == "success")
  and any(.steps[]; .name == "Verify and promote exact tested assets" and .conclusion == "success")
) | .id]' <<< "$jobs")"
test "$(jq -r 'length' <<< "$job_ids")" -eq 1
job_id="$(jq -r '.[0]' <<< "$job_ids")"
[[ "$job_id" =~ ^[1-9][0-9]*$ ]]

# The pinned shared provider logs the exact run/attempt artifact supplied to
# actions/download-artifact. Limit parsing to that action's single with: block.
log="$(gh api "repos/${GITHUB_REPOSITORY}/actions/jobs/${job_id}/logs" | tr -d '\r')"
block="$(awk '
  /##\[group\]Run actions\/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/ { inside = 1; count++; next }
  inside && /##\[endgroup\]/ { inside = 0; next }
  inside { print }
  END { if (count != 1) exit 1 }
' <<< "$log")"
artifact_identity="$(sed -nE 's/^.*[[:space:]]name: (ran-ecwid-shop-teaser-release-([1-9][0-9]*)-([1-9][0-9]*))$/\1 \2 \3/p' <<< "$block")"
test "$(printf '%s\n' "$artifact_identity" | sed '/^$/d' | wc -l)" -eq 1
read -r artifact_name quality_run_id quality_attempt <<< "$artifact_identity"

quality="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${quality_run_id}/attempts/${quality_attempt}")"
jq -e --arg sha "$RAN_ADMITTED_SHA" --arg repo "$GITHUB_REPOSITORY" --argjson id "$quality_run_id" --argjson attempt "$quality_attempt" '
  .id == $id and .run_attempt == $attempt
  and .event == "push" and .path == ".github/workflows/quality.yml"
  and .head_sha == $sha and .head_branch == "main"
  and .head_repository.full_name == $repo
  and .status == "completed" and .conclusion == "success"
' <<< "$quality" >/dev/null

artifacts="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${quality_run_id}/artifacts?name=${artifact_name}")"
jq -e --arg name "$artifact_name" --argjson run "$quality_run_id" '
  [.artifacts[] | select(.name == $name and .expired == false and .workflow_run.id == $run)]
  | length == 1
' <<< "$artifacts" >/dev/null

mkdir -p promotion
gh run download "$quality_run_id" --name "$artifact_name" --dir promotion --repo "$GITHUB_REPOSITORY"
manifest=promotion/ran-profile-b-promotion.json
test -f "$manifest"
version="${RAN_RELEASE_TAG#v}"
archive="ran-ecwid-shop-teaser-${version}.zip"
checksum="${archive}.sha256"
jq -e --arg repo "$GITHUB_REPOSITORY" --arg sha "$RAN_ADMITTED_SHA" --arg tag "$RAN_RELEASE_TAG" --arg archive "$archive" --arg checksum "$checksum" '
  .schema == "ran-profile-b-promotion" and .schema_version == 1
  and .repository == $repo and .quality_commit == $sha
  and .source_commit == $sha and .tag == $tag
  and ([.assets[].name] | sort) == ([$archive, $checksum] | sort)
  and all(.assets[]; (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))
' "$manifest" >/dev/null
for name in "$archive" "$checksum"; do
  expected="$(jq -er --arg name "$name" '[.assets[] | select(.name == $name)] | if length == 1 then .[0].sha256 else error("Expected one exact artifact asset.") end' "$manifest")"
  test "$(sha256sum "promotion/$name" | awk '{ print $1 }')" = "$expected"
done
(cd promotion && sha256sum --check --strict "$checksum")

release="$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${RAN_RELEASE_TAG}")"
jq -e --arg sha "$RAN_ADMITTED_SHA" --arg tag "$RAN_RELEASE_TAG" --slurpfile manifest "$manifest" '
  .tag_name == $tag and .target_commitish == $sha
  and .draft == false and .prerelease == false and .immutable == true
  and ([.assets[] | {name, digest}] | sort_by(.name))
    == ([$manifest[0].assets[] | {name, digest: ("sha256:" + .sha256)}] | sort_by(.name))
' <<< "$release" >/dev/null

printf 'deploy-required=true\nquality-run=%s\nquality-attempt=%s\nartifact-name=%s\n' \
  "$quality_run_id" "$quality_attempt" "$artifact_name" >> "$GITHUB_OUTPUT"
