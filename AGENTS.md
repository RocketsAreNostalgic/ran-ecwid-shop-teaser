# AGENTS.md

## Project contract

This is the standalone RAN Ecwid Shop Teaser WordPress plugin repository inside
a larger local WordPress installation. Work in this directory unless the task
explicitly concerns the parent site.

The supported baseline is WordPress 6.5+ and PHP 8.0+. Keep the plugin header,
`composer.json`, PHPCS configuration, CI, and documentation aligned whenever
that compatibility contract changes. Do not raise that baseline as part of
tooling or workflow work.

## Dex: plans and execution record

Use Dex for non-trivial plans and implementation work. Its local state is
private and ignored by Git.

```sh
dex --storage-path .dex status
dex --storage-path .dex create "Short outcome" --description "Scope, acceptance criteria, and checks"
dex --storage-path .dex start <id>
dex --storage-path .dex complete <id> --result "What changed and how it was verified" --commit <sha>
```

- Use one parent task per meaningful outcome and child tasks for independently
  verifiable slices.
- Record decisions, validation, and follow-up work in the Dex task result.
- Do not commit, copy, delete, or externally sync `.dex` without explicit
  direction.
- Keep durable project decisions in tracked Markdown documentation; Dex is the
  working plan and execution ledger, not published project history.

## WordPress skills

The project-scoped WordPress skills live in `.codex/skills/`. Read the relevant
`SKILL.md` before working in its area:

- `wordpress-router` and `wp-project-triage` for initial orientation.
- `wp-plugin-development` for plugin structure, hooks, settings, security,
  and WordPress conventions.
- `wp-wpcli-and-ops` for WP-CLI or operational changes.
- `wp-phpstan` when adding or changing static analysis.

## Development workflow

Install from the tracked locks; never use a setup script that deletes them.

```sh
composer install --no-interaction
pnpm install --frozen-lockfile
pnpm check
composer check
pnpm check:generated
pnpm test:php
pnpm release:verify
```

Source block assets live in `blocks/` and compiled runtime assets in
`build/blocks/` are committed. Run `pnpm build` and `pnpm i18n:pot` for
relevant source changes, then review and stage the generated build assets and
`languages/ran-ecwid-shop-teaser.pot`. The pre-commit hook enforces those
checks for its configured source paths; tooling, documentation, and
release-only changes must not cause an unnecessary rebuild.

## Quality profile and ownership

This repository uses the RAN `wordpress-plugin` quality profile.

- `ran/coding-standards` owns the organisation-wide PHP, WordPress Coding
  Standards, and PHPCompatibility ancestry. This repository continues to own
  its WordPress 6.5+ / PHP 8.0+ support range, source paths, identity, and
  justified PHPCS exceptions.
- `@rocketsarenostalgic/quality-config` owns the shared ESLint, Prettier, and
  Stylelint ancestry. This repository continues to own source selection,
  generated/vendor exclusions, applicability, and product-specific
  exceptions, including `@wordpress/no-unsafe-wp-apis`.
- `composer check` runs syntax and PHPCS standards; `composer test:integration`
  runs WordPress integration PHPUnit in the compatibility matrix. These are
  the canonical Composer commands. WordPress integration PHPUnit remains owned by the
  compatibility matrix.
- `pnpm check` remains the deterministic package-level quality contract.
- Archive identity, generated block/POT drift, fresh-ZIP install/activation,
  compatibility coverage, and Plugin Check remain repository-owned specialist
  gates. Shared Profile B admits the exact Release Please candidate and requires
  its full Quality coverage.

## Git and commits

Use Conventional Commits with one coherent change per commit. `feat:` and
`fix:` are releasable; use `chore:`, `docs:`, `test:`, `build:`, or `ci:` for
non-release work. Do not commit `vendor/`, `node_modules/`, `.dex`, test
caches, editor-local files, or generated artifacts outside the tracked build
assets and POT.

## Release automation

Use the global `$release-please` skill before configuring, changing, or
operating this repository's release workflow.

This is a standalone GitHub repository. Release Please should run from `main`
with a manifest-driven PHP release configuration. The WordPress plugin header
and runtime constant in `ran-ecwid-shop-teaser.php`, `readme.txt` stable tag,
`package.json`, and tracked POT project version must all agree with the release
version. The normal PHP strategy does not update those WordPress-specific
sources automatically; configure and test explicit extra-file updates.

The build and quality workflows derive archive filenames from the plugin
metadata and verify that version against the release tag. Keep packaging or
WordPress.org deployment separate from Release Please.

Shared Profile B consumes an exact successful same-repository `Quality` run
for `main`, runs Release Please, qualifies the exact canonical release PR,
retrieves the exact main run/attempt ZIP and checksum, verifies the promotion
manifest and digests, then attaches those same bytes to Release Please's draft.
It publishes and reads back the immutable tag, target, and two public assets.
The repository retains the deterministic builder, archive manifest as CI
evidence, generated block/POT gates, WordPress integration, Plugin Check, and
fresh ZIP installation. Release Please owns versions, changelog, PR, tag, and
GitHub Release lifecycle. Do not add repository-local merge classifiers,
candidate marker state, mutable recovery, or publication scripts.

Release Please PRs may be drafts; mark the exact qualified candidate ready
before its protected-main merge. WordPress.org remains disabled in
`wordpress-org/deployment.json` and is an optional downstream observer of a
successful immutable GitHub release. The historical bootstrap boundary and
initial manifest version are preserved as repository history; no historical
replay or recovery path is part of this workflow.

## External AI agent prohibition

Do not invoke, delegate work to, tag, enable, or otherwise use Blacksmith [code]smith,
`@codesmith-bot`, Blacksmith Autofix, Blacksmith CI Tuning, Blacksmith Testbox agents,
or any other Blacksmith AI/agent feature.

Blacksmith may be used only as infrastructure for ordinary GitHub Actions runners where
the repository workflow explicitly specifies a Blacksmith runner.

Do not click or trigger "Enable autofix", do not ask [code]smith to investigate or repair
CI, and do not call Blacksmith agent/MCP/CLI/API features that perform AI inference.

If CI fails, inspect GitHub Actions logs directly and diagnose/fix the failure yourself.

This prohibition is a cost-control requirement and must not be overridden by convenience,
CI failure, review comments, or suggestions from GitHub/Blacksmith UI.
