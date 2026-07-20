# Pre-release checklist

Use this as the final outstanding-work list before publishing RAN Ecwid Shop
Teaser to WordPress.org. The plugin has release tooling and a WordPress.org
handoff path, but it still needs final publication assets, validation, and
service-policy sign-off.

## Publish blockers

-   [ ] Confirm the committed directory artwork in `wordpress-org/assets/` is
        licence-cleared, project-owned, and approved for public directory use.
-   [ ] Keep `wordpress-org/DEPLOYMENT.md` aligned with the committed
        `wordpress-org/assets/` location and the current release contract.
-   [ ] Confirm the WordPress.org plugin slug `ran-ecwid-shop-teaser`,
        contributor account, support ownership, and public repository links are
        final.
-   [ ] Review `readme.txt` against the current WordPress.org readme validator,
        including tags, Ecwid external-service disclosures, stable tag `1.1.1`,
        and the declared `Tested up to` value.
-   [ ] Run the full local release gate from a clean worktree:

          ```sh
          pnpm install --frozen-lockfile
          composer install --no-interaction
          pnpm check
          composer lint
          composer lint:compat
          pnpm check:generated
          pnpm release:verify
          bash scripts/create-release-assets.sh v1.1.1
          bash scripts/deploy-wordpress-org.sh dist/ran-ecwid-shop-teaser-1.1.1.zip \
              dist/ran-ecwid-shop-teaser-1.1.1.zip.sha256 \
              dist/ran-ecwid-shop-teaser-1.1.1.manifest.json --allow-disabled
          ```

-   [ ] Run the WordPress integration tests and fresh-ZIP install/plugin-check path
        represented in `.github/workflows/quality.yml` without the database-backed
        integration matrix.
-   [ ] Install the generated ZIP into a clean WordPress site with the official
        Ecwid plugin configured and verify editor preview, frontend rendering,
        cache fallback, unavailable-product state, keyboard focus, and diagnostic
        visibility.
-   [ ] Verify the fallback-filter path without the official Ecwid plugin so the
        readme claim remains true.
-   [ ] Confirm the release ZIP contains only the builder's allowlisted runtime
        paths: the plugin bootstrap, `includes/`, built `build/blocks/` assets,
        translation template, licence, and `readme.txt`. Source-only,
        development, test, vendor-cache, and WordPress.org asset-directory
        files must remain excluded.
-   [ ] Use the protected `wordpress-org` environment to deploy the validated
        GitHub release to SVN `trunk` and tag `1.1.1`. Sync approved directory
        artwork to `/assets` only through an explicitly approved first deployment.

## Translation readiness

-   [ ] Confirm all user-facing PHP and JavaScript strings are wrapped in the
        appropriate WordPress i18n function with the `ran-ecwid-shop-teaser` text
        domain. Block metadata strings in `block.json` are covered by its
        `textdomain` value and the POT extraction command.
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
