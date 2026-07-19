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

-   Use one parent task per meaningful outcome and child tasks for independently
    verifiable slices.
-   Record decisions, validation, and follow-up work in the Dex task result.
-   Do not commit, copy, delete, or externally sync `.dex` without explicit
    direction.
-   Keep durable project decisions in tracked Markdown documentation; Dex is the
    working plan and execution ledger, not published project history.

## WordPress skills

The project-scoped WordPress skills live in `.codex/skills/`. Read the relevant
`SKILL.md` before working in its area:

-   `wordpress-router` and `wp-project-triage` for initial orientation.
-   `wp-plugin-development` for plugin structure, hooks, settings, security,
    and WordPress conventions.
-   `wp-wpcli-and-ops` for WP-CLI or operational changes.
-   `wp-phpstan` when adding or changing static analysis.

## Development workflow

Install from the tracked locks; never use a setup script that deletes them.

```sh
composer install --no-interaction
pnpm install --frozen-lockfile
pnpm check
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

Do not enable automated releases until the build/quality workflow derives its
archive filename from the plugin metadata rather than the current hard-coded
`1.0.0` value. Keep packaging or WordPress.org deployment separate from
Release Please.

Treat the existing initial-release preparation commit as the bootstrap
boundary, preserve version `1.0.0` in the initial manifest, and review the
first generated release PR before merging it.
