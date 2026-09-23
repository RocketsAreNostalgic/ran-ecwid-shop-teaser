#!/usr/bin/env python3
"""Exercise the actual WordPress.org observer steps with disposable API fixtures."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import zipfile


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/deploy-wordpress-org.yml").read_text()
SHA = "a" * 40
TAG = "v1.3.1"
ARCHIVE = "ran-ecwid-shop-teaser-1.3.1.zip"


def step(name):
    lines = WORKFLOW.splitlines()
    marker = f"- name: {name}"
    start = next(i for i, line in enumerate(lines) if line.strip() == marker)
    run = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == "run: |")
    indent = len(lines[run]) - len(lines[run].lstrip())
    end = run + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        end += 1
    return textwrap.dedent("\n".join(lines[run + 1 : end])) + "\n"


def execute(script, directory, env, expected=0):
    result = subprocess.run(
        ["bash", "-euo", "pipefail", "-c", script],
        cwd=directory,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    assert (result.returncode == 0) == (expected == 0), (
        f"expected {'success' if expected == 0 else 'failure'}: "
        f"{result.returncode}\n{result.stdout}\n{result.stderr}"
    )
    return result


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value)


def mock_command(path, code):
    write(path, "#!/usr/bin/env bash\nset -euo pipefail\n" + code)
    path.chmod(0o755)


def release(tag=TAG, sha=SHA, **changes):
    return {
        "tag_name": tag,
        "target_commitish": sha,
        "draft": False,
        "prerelease": False,
        "immutable": True,
        "assets": [],
        **changes,
    }


with tempfile.TemporaryDirectory(prefix="ecwid-observer-contract-") as tmp:
    tmp = Path(tmp)
    bindir = tmp / "bin"
    bindir.mkdir()
    mock_command(bindir / "git", 'test "$1" = rev-parse; printf "%s\\n" "$MOCK_SHA"\n')
    mock_command(
        bindir / "gh",
        """
if [[ "$1" == api ]]; then
  if [[ "$*" == *"/actions/runs/${MOCK_PROVIDER_RUN_ID}/attempts/1/jobs"* ]]; then cat "$MOCK_PROVIDER_JOBS"; exit; fi
  if [[ "$*" == *"/actions/runs/${MOCK_PROVIDER_RUN_ID}/attempts/1"* ]]; then cat "$MOCK_PROVIDER_RUN"; exit; fi
  if [[ "$*" == *"/actions/jobs/902/logs"* ]]; then cat "$MOCK_PROVIDER_LOG"; exit; fi
  if [[ "$*" == *"/actions/runs/${MOCK_QUALITY_RUN_ID}/attempts/1"* ]]; then cat "$MOCK_QUALITY_RUN"; exit; fi
  if [[ "$*" == *"/actions/runs/${MOCK_QUALITY_RUN_ID}/artifacts"* ]]; then cat "$MOCK_QUALITY_ARTIFACTS"; exit; fi
  if [[ "$*" == *'/releases?per_page=100'* ]]; then cat "$MOCK_RELEASE_PAGES"; exit; fi
  if [[ "$*" == *'/git/ref/tags/'* ]]; then cat "$MOCK_TAG_REF"; exit; fi
  if [[ "$*" == *'/releases/tags/'* ]]; then cat "$MOCK_RELEASE_JSON"; exit; fi
fi
if [[ "$1" == run && "$2" == download ]]; then
  shift 3
  target=''
  while (($#)); do
    case "$1" in
      --dir) target="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cp "$MOCK_ASSET_DIR"/* "$target/"
  exit
fi
if [[ "$1" == release && "$2" == download ]]; then
  shift 2
  asset=''
  target=''
  while (($#)); do
    case "$1" in
      --pattern) asset="$2"; shift 2 ;;
      --dir) target="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cp "$MOCK_ASSET_DIR/$asset" "$target/$asset"
  exit
fi
exit 1
""",
    )
    env = dict(os.environ)
    env.update(
        PATH=f"{bindir}:{env['PATH']}",
        GITHUB_REPOSITORY="RocketsAreNostalgic/ran-ecwid-shop-teaser",
        RAN_ADMITTED_SHA=SHA,
        ADMITTED_SHA=SHA,
        MOCK_SHA=SHA,
        TAG_NAME=TAG,
        MOCK_RELEASE_PAGES=str(tmp / "pages.json"),
        MOCK_TAG_REF=str(tmp / "tag.json"),
        MOCK_RELEASE_JSON=str(tmp / "release.json"),
        MOCK_ASSET_DIR=str(tmp / "assets"),
        MOCK_PROVIDER_RUN_ID="901",
        MOCK_QUALITY_RUN_ID="801",
        MOCK_PROVIDER_RUN=str(tmp / "provider.json"),
        MOCK_PROVIDER_JOBS=str(tmp / "provider-jobs.json"),
        MOCK_PROVIDER_LOG=str(tmp / "provider.log"),
        MOCK_QUALITY_RUN=str(tmp / "quality.json"),
        MOCK_QUALITY_ARTIFACTS=str(tmp / "artifacts.json"),
    )
    write(Path(env["MOCK_TAG_REF"]), json.dumps({"object": {"type": "commit", "sha": SHA}}))
    admission = step("Resolve exact immutable release")
    contract = step("Read committed deployment contract")
    verify = step("Download and verify exact immutable GitHub release assets")

    for name, items, success in (
        ("stable", [release()], True),
        ("prerelease", [release(prerelease=True)], True),
        ("draft", [release(draft=True)], True),
        ("mutable", [release(immutable=False)], True),
        ("other-commit", [release(sha="b" * 40)], True),
        ("duplicate", [release(), release()], False),
    ):
        write(Path(env["MOCK_RELEASE_PAGES"]), json.dumps([items]))
        output = tmp / f"{name}.output"
        variant = dict(env, GITHUB_OUTPUT=str(output))
        execute(admission, tmp, variant, 0 if success else 1)
        if success:
            expected = "release-found=true" if name == "stable" else "release-found=false"
            assert expected in output.read_text(), name

    write(Path(env["MOCK_RELEASE_PAGES"]), json.dumps([[release()]]))
    write(Path(env["MOCK_TAG_REF"]), json.dumps({"object": {"type": "commit", "sha": "b" * 40}}))
    execute(admission, tmp, dict(env, GITHUB_OUTPUT=str(tmp / "bad-tag.output")), 1)
    write(Path(env["MOCK_TAG_REF"]), json.dumps({"object": {"type": "commit", "sha": SHA}}))

    deployment = tmp / "wordpress-org/deployment.json"
    write(deployment, json.dumps({"enabled": False, "syncListingAssets": False}))
    contract_env = dict(env, GITHUB_OUTPUT=str(tmp / "contract.output"))
    execute(contract, tmp, contract_env)
    assert "enabled=false\nsync-assets=false" in Path(contract_env["GITHUB_OUTPUT"]).read_text()
    write(deployment, json.dumps({"enabled": False}))
    execute(contract, tmp, dict(env, GITHUB_OUTPUT=str(tmp / "missing-sync.output")), 1)

    assets = Path(env["MOCK_ASSET_DIR"])
    assets.mkdir()
    write(assets / ARCHIVE, "exact tested ZIP fixture\n")
    checksum = ARCHIVE + ".sha256"
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    write(assets / checksum, f"{digest(assets / ARCHIVE)}  {ARCHIVE}\n")
    valid = release(
        assets=[
            {"name": ARCHIVE, "digest": "sha256:" + digest(assets / ARCHIVE)},
            {"name": checksum, "digest": "sha256:" + digest(assets / checksum)},
        ]
    )

    def check_assets(label, data, expected=0):
        write(Path(env["MOCK_RELEASE_JSON"]), json.dumps(data))
        work = tmp / label
        work.mkdir()
        execute(verify, work, env, expected)

    check_assets("valid-assets", valid)
    bad = json.loads(json.dumps(valid))
    bad["assets"][0]["digest"] = "sha256:" + "b" * 64
    check_assets("bad-digest", bad, 1)
    bad = json.loads(json.dumps(valid))
    bad["assets"].append({"name": "extra.txt", "digest": "sha256:" + "c" * 64})
    check_assets("extra-asset", bad, 1)
    check_assets("prerelease-readback", dict(valid, prerelease=True), 1)
    check_assets("wrong-target", dict(valid, target_commitish="b" * 40), 1)

    promotion = {
        "schema": "ran-profile-b-promotion",
        "schema_version": 1,
        "repository": env["GITHUB_REPOSITORY"],
        "quality_commit": SHA,
        "source_commit": SHA,
        "tag": TAG,
        "assets": [
            {"name": ARCHIVE, "sha256": digest(assets / ARCHIVE)},
            {"name": checksum, "sha256": digest(assets / checksum)},
        ],
    }
    write(assets / "ran-profile-b-promotion.json", json.dumps(promotion))
    write(Path(env["MOCK_RELEASE_JSON"]), json.dumps(valid))
    provider = {
        "id": 901,
        "run_attempt": 1,
        "event": "workflow_run",
        "path": ".github/workflows/release-please.yml",
        "head_sha": SHA,
        "head_branch": "main",
        "head_repository": {"full_name": env["GITHUB_REPOSITORY"]},
        "status": "completed",
        "conclusion": "success",
    }
    quality = dict(
        provider,
        id=801,
        event="push",
        path=".github/workflows/quality.yml",
    )
    jobs = {
        "jobs": [
            {
                "id": 902,
                "conclusion": "success",
                "steps": [
                    {"name": "Download exact Quality artifact", "conclusion": "success"},
                    {"name": "Verify and promote exact tested assets", "conclusion": "success"},
                ],
            }
        ]
    }
    artifact_name = "ran-ecwid-shop-teaser-release-801-1"
    write(Path(env["MOCK_PROVIDER_RUN"]), json.dumps(provider))
    write(Path(env["MOCK_QUALITY_RUN"]), json.dumps(quality))
    write(Path(env["MOCK_PROVIDER_JOBS"]), json.dumps(jobs))
    write(
        Path(env["MOCK_PROVIDER_LOG"]),
        "2026-09-23T00:00:00Z ##[group]Run actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c\n"
        f"2026-09-23T00:00:00Z   name: {artifact_name}\n"
        "2026-09-23T00:00:00Z ##[endgroup]\n",
    )
    write(
        Path(env["MOCK_QUALITY_ARTIFACTS"]),
        json.dumps(
            {
                "artifacts": [
                    {
                        "name": artifact_name,
                        "expired": False,
                        "workflow_run": {"id": 801},
                    }
                ]
            }
        ),
    )

    evidence_env = dict(
        env,
        GITHUB_OUTPUT=str(tmp / "promotion.output"),
        RAN_PROVIDER_RUN_ID="901",
        RAN_PROVIDER_ATTEMPT="1",
        RAN_RELEASE_TAG=TAG,
    )
    helper = ROOT / "scripts/verify-wordpress-org-promotion.sh"
    proof_dir = tmp / "promotion-proof"
    proof_dir.mkdir()
    execute(f"bash {helper}", proof_dir, evidence_env)
    assert f"quality-run=801\nquality-attempt=1\nartifact-name={artifact_name}" in Path(
        evidence_env["GITHUB_OUTPUT"]
    ).read_text()
    bad = json.loads(json.dumps(valid))
    bad["assets"][0]["digest"] = "sha256:" + "b" * 64
    write(Path(env["MOCK_RELEASE_JSON"]), json.dumps(bad))
    denied = tmp / "promotion-bad-release"
    denied.mkdir()
    execute(f"bash {helper}", denied, dict(evidence_env, GITHUB_OUTPUT=str(tmp / "denied.output")), 1)
    write(Path(env["MOCK_RELEASE_JSON"]), json.dumps(valid))
    jobs["jobs"][0]["steps"][1]["conclusion"] = "skipped"
    write(Path(env["MOCK_PROVIDER_JOBS"]), json.dumps(jobs))
    denied = tmp / "promotion-bad-provider"
    denied.mkdir()
    execute(f"bash {helper}", denied, dict(evidence_env, GITHUB_OUTPUT=str(tmp / "denied-job.output")), 1)
    write(Path(env["MOCK_PROVIDER_JOBS"]), json.dumps({"jobs": []}))

    condition = WORKFLOW.split("    contract:", 1)[1].split("        runs-on:", 1)[0]
    for guard in (
        "github.event.workflow_run.event == 'workflow_run'",
        "github.event.workflow_run.conclusion == 'success'",
        "github.event.workflow_run.head_repository.full_name == github.repository",
        "github.event.workflow_run.head_repository.id == github.repository_id",
        "github.event.workflow_run.path == '.github/workflows/release-please.yml'",
    ):
        assert guard in condition, guard

    # A successful observer rerun may see an existing SVN tag. It must accept
    # only byte-identical tagged files and refuse a different published tree.
    deploy_root = tmp / "deploy-root"
    (deploy_root / "scripts").mkdir(parents=True)
    shutil.copy2(ROOT / "scripts/deploy-wordpress-org.sh", deploy_root / "scripts")
    write(
        deploy_root / "wordpress-org/deployment.json",
        json.dumps(
            {
                "enabled": True,
                "syncListingAssets": False,
                "wordpressOrgSlug": "ecwid-fixture",
                "packageSlug": "ran-ecwid-shop-teaser",
                "mainPluginFile": "ran-ecwid-shop-teaser.php",
                "listingAssetsDirectory": "wordpress-org/assets",
            }
        ),
    )
    plugin = "* Version: 1.3.1\n"
    write(deploy_root / "ran-ecwid-shop-teaser.php", plugin)
    write(deploy_root / ".release-please-manifest.json", json.dumps({".": "1.3.1"}))
    deploy_zip = deploy_root / ARCHIVE
    with zipfile.ZipFile(deploy_zip, "w") as bundle:
        bundle.writestr("ran-ecwid-shop-teaser/ran-ecwid-shop-teaser.php", plugin)
    deploy_checksum = deploy_root / (ARCHIVE + ".sha256")
    write(deploy_checksum, f"{digest(deploy_zip)}  {ARCHIVE}\n")
    published = tmp / "published"
    write(published / "ran-ecwid-shop-teaser.php", plugin)
    qualified = tmp / "qualified"
    write(qualified / "ran-ecwid-shop-teaser.php", plugin)
    artwork = "qualified listing artwork\n"
    write(deploy_root / "wordpress-org/assets/icon.svg", artwork)
    qualified_assets = tmp / "qualified-assets"
    write(qualified_assets / "icon.svg", artwork)
    mock_command(
        bindir / "svn",
        """
target="${@: -1}"
case "$1" in
  checkout)
    mkdir -p "$target/trunk" "$target/assets"
    if [[ "${MOCK_OLD_ASSET:-false}" == true ]]; then
      printf '%s\n' 'obsolete artwork' > "$target/assets/old-icon.svg"
    fi
    if [[ -n "${MOCK_TRUNK_VERSION:-}" ]]; then
      printf '* Version: %s\\n' "$MOCK_TRUNK_VERSION" > "$target/trunk/ran-ecwid-shop-teaser.php"
    fi ;;
  ls)
    if [[ "$2" == */tags ]]; then printf '%s\\n' "${MOCK_SVN_TAGS:-}"; exit 0; fi
    if [[ "$2" == */tags/1.3.1 ]]; then [[ "$MOCK_EXISTING_TAG" == true ]]; exit; fi
    exit 1 ;;
  export)
    if [[ "$2" == -r ]]; then
      if [[ "$*" == *'/assets@371'* ]]; then
        printf '%s\n' "$*" > "$MOCK_ASSET_EXPORT_ARGS"
        cp -a "$MOCK_QUALIFIED_ASSETS" "$target"
        if [[ "${MOCK_COMMITTED_ASSETS_DIFF:-false}" == true ]]; then
          printf '%s\n' 'concurrent SVN artwork' > "$target/unqualified.svg"
        fi
      else
        printf '%s\n' "$*" > "$MOCK_EXPORT_ARGS"
        cp -a "$MOCK_QUALIFIED_DIR" "$target"
        if [[ "${MOCK_COMMITTED_DIFF:-false}" == true ]]; then
          printf '%s\n' 'concurrent SVN change' > "$target/unqualified.php"
        fi
        if [[ "${MOCK_COMMITTED_LINK:-false}" == true ]]; then
          rm "$target/ran-ecwid-shop-teaser.php"
          ln -s "$MOCK_QUALIFIED_DIR/ran-ecwid-shop-teaser.php" "$target/ran-ecwid-shop-teaser.php"
        fi
      fi
    else cp -a "$MOCK_PUBLISHED_DIR" "$target"; fi ;;
  status)
    if [[ "$2" == */assets && "${MOCK_OLD_ASSET:-false}" == true ]]; then
      printf '!       %s\n' "$2/old-icon.svg"
    fi ;;
  add) : ;;
  rm) printf '%s\n' "$*" > "$MOCK_SVN_RM_ARGS" ;;
  commit) printf '%s\n' "${MOCK_COMMIT_OUTPUT:-Committed revision 371.}" ;;
  copy) printf '%s\n' "$*" > "$MOCK_COPY_ARGS" ;;
  *) exit 1 ;;
esac
""",
    )
    mock_command(
        bindir / "rsync",
        """
source="${@: -2:1}"
target="${@: -1}"
if [[ "$*" == *'--delete'* ]]; then
  find "$target" -mindepth 1 -maxdepth 1 -type f -delete
fi
cp -a "$source/." "$target"
""",
    )
    deploy_env = dict(
        env,
        MOCK_PUBLISHED_DIR=str(published),
        MOCK_QUALIFIED_DIR=str(qualified),
        MOCK_QUALIFIED_ASSETS=str(qualified_assets),
        MOCK_EXPORT_ARGS=str(tmp / "svn-export-args"),
        MOCK_ASSET_EXPORT_ARGS=str(tmp / "svn-asset-export-args"),
        MOCK_EXISTING_TAG="true",
        MOCK_SVN_TAGS="1.3.1/",
        MOCK_TRUNK_VERSION="",
        MOCK_COPY_ARGS=str(tmp / "svn-copy-args"),
        MOCK_SVN_RM_ARGS=str(tmp / "svn-rm-args"),
        WORDPRESS_ORG_USERNAME="fixture",
        WORDPRESS_ORG_PASSWORD="fixture",
    )
    command = f"bash scripts/deploy-wordpress-org.sh {deploy_zip} {deploy_checksum}"
    execute(command, deploy_root, deploy_env)
    write(published / "ran-ecwid-shop-teaser.php", "different published bytes\n")
    assert "different bytes" in execute(command, deploy_root, deploy_env, 1).stderr
    stale = execute(
        command,
        deploy_root,
        dict(deploy_env, MOCK_EXISTING_TAG="false", MOCK_SVN_TAGS="1.4.0/"),
        1,
    )
    assert "newer stable tag 1.4.0" in stale.stderr
    partial = execute(
        command,
        deploy_root,
        dict(
            deploy_env,
            MOCK_EXISTING_TAG="false",
            MOCK_SVN_TAGS="",
            MOCK_TRUNK_VERSION="1.4.0",
        ),
        1,
    )
    assert "trunk is already at 1.4.0" in partial.stderr
    untagged = execute(
        command,
        deploy_root,
        dict(
            deploy_env,
            MOCK_EXISTING_TAG="false",
            MOCK_SVN_TAGS="",
            MOCK_TRUNK_VERSION="1.3.1",
        ),
        1,
    )
    assert "trunk is already at 1.3.1" in untagged.stderr
    new_deploy = dict(deploy_env, MOCK_EXISTING_TAG="false", MOCK_SVN_TAGS="")
    execute(command, deploy_root, new_deploy)
    copy_args = Path(new_deploy["MOCK_COPY_ARGS"]).read_text()
    assert copy_args.startswith("copy -r 371 https://plugins.svn.wordpress.org/ecwid-fixture/trunk@371 ")
    export_args = Path(new_deploy["MOCK_EXPORT_ARGS"]).read_text()
    assert "https://plugins.svn.wordpress.org/ecwid-fixture/trunk@371" in export_args
    Path(new_deploy["MOCK_COPY_ARGS"]).unlink()
    concurrent = execute(
        command,
        deploy_root,
        dict(new_deploy, MOCK_COMMITTED_DIFF="true"),
        1,
    )
    assert "Committed SVN trunk differs from the qualified ZIP" in concurrent.stderr
    assert not Path(new_deploy["MOCK_COPY_ARGS"]).exists()
    symlink = execute(
        command,
        deploy_root,
        dict(new_deploy, MOCK_COMMITTED_LINK="true"),
        1,
    )
    assert "Committed SVN trunk differs from the qualified ZIP" in symlink.stderr
    assert not Path(new_deploy["MOCK_COPY_ARGS"]).exists()
    bad_commit = execute(
        command,
        deploy_root,
        dict(new_deploy, MOCK_COMMIT_OUTPUT="Committed an unknown revision."),
        1,
    )
    assert "did not report one committed revision" in bad_commit.stderr
    assert not Path(new_deploy["MOCK_COPY_ARGS"]).exists()
    deployment = deploy_root / "wordpress-org/deployment.json"
    contract = json.loads(deployment.read_text())
    contract["syncListingAssets"] = True
    write(deployment, json.dumps(contract))
    sync_command = command + " --sync-assets"
    synced = dict(new_deploy, MOCK_OLD_ASSET="true")
    execute(sync_command, deploy_root, synced)
    assert "old-icon.svg" in Path(synced["MOCK_SVN_RM_ARGS"]).read_text()
    asset_export_args = Path(new_deploy["MOCK_ASSET_EXPORT_ARGS"]).read_text()
    assert "https://plugins.svn.wordpress.org/ecwid-fixture/assets@371" in asset_export_args
    Path(new_deploy["MOCK_COPY_ARGS"]).unlink()
    bad_artwork = execute(
        sync_command,
        deploy_root,
        dict(new_deploy, MOCK_COMMITTED_ASSETS_DIFF="true"),
        1,
    )
    assert "Committed SVN listing assets differ" in bad_artwork.stderr
    assert not Path(new_deploy["MOCK_COPY_ARGS"]).exists()

print("WordPress.org observer, exact Profile B evidence, and SVN rollback fixtures passed.")
