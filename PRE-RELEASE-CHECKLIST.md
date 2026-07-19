# Pre-release checklist

Use this as the final outstanding-work list before publishing RAN Ecwid Shop
Teaser to WordPress.org. The plugin has release tooling and a WordPress.org
handoff path, but it still needs final publication assets, validation, and
service-policy sign-off.

## Publish blockers

-   [ ] Finish the WordPress.org asset-directory migration currently visible in
        the worktree: the old `wordpress-org-assets/` files are deleted and the
        replacement files now live under `wordpress-org/assets/`.
-   [ ] Update `wordpress-org/README.md` so it points at the actual
        `wordpress-org/assets/` location, not the retired
        `../wordpress-org-assets/` path.
-   [ ] Confirm the WordPress.org plugin slug `ran-ecwid-shop-teaser`,
        contributor account, support ownership, and public repository links are
        final.
-   [ ] Confirm the banner and icon files in `wordpress-org/assets/` are
        licence-cleared, project-owned, and approved for public directory use.
-   [ ] Create the planned WordPress.org screenshots listed in
        `wordpress-org/README.md`:
        `screenshot-1.png`, `screenshot-2.png`, and `screenshot-3.png`.
-   [ ] Update `readme.txt` with a `== Screenshots ==` section once the screenshot
        files exist, or remove the screenshot expectations from the WordPress.org
        handoff notes.
-   [ ] Review `readme.txt` against the current WordPress.org readme validator,
        including tags, Ecwid external-service disclosures, stable tag `1.0.0`,
        and the declared `Tested up to` value.
-   [ ] Run the full local release gate from a clean worktree:

        ```sh
        pnpm install --frozen-lockfile
        composer install
        pnpm check
        composer lint
        composer lint:compat
        pnpm i18n:pot
        pnpm archive
        pnpm archive:check
        pnpm wordpress-org:prepare
        ```

-   [ ] Run the WordPress integration tests and fresh-ZIP install/plugin-check path
        represented in `.github/workflows/quality.yml`.
-   [ ] Install the generated ZIP into a clean WordPress site with the official
        Ecwid plugin configured and verify editor preview, frontend rendering,
        cache fallback, unavailable-product state, keyboard focus, and diagnostic
        visibility.
-   [ ] Verify the fallback-filter path without the official Ecwid plugin so the
        readme claim remains true.
-   [ ] Confirm the release ZIP contains the built `build/blocks/` runtime assets
        and excludes source-only, development, test, vendor-cache, and
        WordPress.org asset-directory files.
-   [ ] Copy the validated release contents to WordPress.org SVN `trunk`, tag
        `1.0.0`, and upload only approved directory artwork/screenshots to
        `/assets`.

## Translation readiness

-   [ ] Confirm all user-facing PHP and JavaScript strings are wrapped in the
        appropriate WordPress i18n function with the
        `ran-ecwid-shop-teaser` text domain. Block metadata strings in
        `block.json` are covered by its `textdomain` value and the POT extraction
        command.
-   [ ] Run the WordPress i18n coding-standard sniff:
        `vendor/bin/phpcs --standard=phpcs.xml.dist --sniffs=WordPress.WP.I18n`.
-   [ ] Regenerate `languages/ran-ecwid-shop-teaser.pot` with `pnpm i18n:pot`
        after all final user-facing copy changes.
-   [ ] Confirm the POT file has no stale source references and is committed with
        the release.
-   [ ] Do not bundle `.po` or `.mo` files unless they are reviewed,
        release-ready translations. WordPress.org translations should normally be
        handled through translate.wordpress.org after approval.
-   [ ] Treat launch translations as optional. Only add `.po` and `.mo` files if
        a fluent reviewer has approved them and there is a specific release reason
        to ship them before WordPress.org language packs exist.

## Nice-to-have before first public launch

-   [ ] Capture a short manual QA note using product imagery that can be
        redistributed in screenshots.
-   [ ] Confirm support wording for stores without credentials, empty categories,
        and expired Ecwid tokens before publishing.
