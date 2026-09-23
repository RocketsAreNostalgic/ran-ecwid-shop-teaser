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
  if [[ "$*" == *'/releases?per_page=100'* ]]; then cat "$MOCK_RELEASE_PAGES"; exit; fi
  if [[ "$*" == *'/git/ref/tags/'* ]]; then cat "$MOCK_TAG_REF"; exit; fi
  if [[ "$*" == *'/releases/tags/'* ]]; then cat "$MOCK_RELEASE_JSON"; exit; fi
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
            expected = "deploy-required=true" if name == "stable" else "deploy-required=false"
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
    mock_command(
        bindir / "svn",
        """
target="${@: -1}"
case "$1" in
  checkout) mkdir -p "$target" ;;
  ls) exit 0 ;;
  export) cp -a "$MOCK_PUBLISHED_DIR" "$target" ;;
  *) exit 1 ;;
esac
""",
    )
    deploy_env = dict(
        env,
        MOCK_PUBLISHED_DIR=str(published),
        WORDPRESS_ORG_USERNAME="fixture",
        WORDPRESS_ORG_PASSWORD="fixture",
    )
    command = f"bash scripts/deploy-wordpress-org.sh {deploy_zip} {deploy_checksum}"
    execute(command, deploy_root, deploy_env)
    write(published / "ran-ecwid-shop-teaser.php", "different published bytes\n")
    execute(command, deploy_root, deploy_env, 1)

print("WordPress.org observer admission, exact assets, and SVN rerun fixtures passed.")
