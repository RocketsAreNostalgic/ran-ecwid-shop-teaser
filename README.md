# RAN Ecwid Shop Teaser

RAN Ecwid Shop Teaser is a standalone dynamic WordPress product-grid block.
Its canonical block name is `ran/ecwid-shop-teaser`.

## Features

- Provides editor previews, caching, and theme-independent baseline styling.
- Reads credentials from the installed Ecwid WordPress plugin by default.
- Safely renders last-good cached or filter-provided cards when Ecwid is
  unavailable.
- Keeps diagnostic information editor-only.

## Requirements

- WordPress 6.5 or newer.
- PHP 8.0 or newer.
- An Ecwid store integration, or filters that provide an Ecwid store ID and API
  token.

## Installation

1. Install the plugin in `wp-content/plugins/ran-ecwid-shop-teaser`.
2. Activate **RAN Ecwid Shop Teaser** in WordPress administration.
3. Configure the Ecwid WordPress plugin, or supply credentials through the
   documented filters.

The committed `build/blocks/` directory is required at runtime. Deploy the
plugin with those compiled assets; the source `blocks/` directory is for
development rather than a production fallback.

## Usage

Insert **Ecwid Shop Teaser** from the core `Widgets` category. Select the
desired category and product count in the block inspector. Published visitors
receive cards from Ecwid when available, then the last-good cache or valid
filter-provided fallback cards.

The editor uses these routes:

- `POST /ran-ecwid-shop-teaser/v1/ecwid-shop-teaser/preview`
- `POST /ran-ecwid-shop-teaser/v1/ecwid-shop-teaser/refresh`

## External service

The plugin optionally retrieves product data from the Ecwid REST API through
the official Ecwid WordPress plugin or credentials supplied by its filters.
That request sends the configured store ID, API token, category ID, and product
query to Ecwid; it is made server-to-server and does not expose the API token
to visitors. Sites using this integration are responsible for reviewing
[Ecwid's terms of service](https://www.ecwid.com/terms-of-service) and
[privacy policy](https://www.ecwid.com/privacy-policy).

## Development

Run commands from this plugin directory:

```sh
pnpm install --frozen-lockfile
pnpm start
pnpm build
pnpm format:check
pnpm check
```

Source files live in `blocks/`. Rebuild `build/blocks/` after block changes and
commit the generated runtime assets with their source.

## Agent workflow

See [AGENTS.md](AGENTS.md) for the local Dex workflow, WordPress skills,
generated-asset rules, quality checks, and release guidance.

## Extensibility and compatibility

The plugin registers only `ran/ecwid-shop-teaser`. Rendered markup uses
`.ran-ecwid-shop-teaser*` and `.ran-ecwid-shop-teaser-card*` classes, with
`--ran-ecwid-shop-teaser--*` presentation variables.

Available filters include `ran_ecwid_shop_teaser_store_id`,
`ran_ecwid_shop_teaser_token`, `ran_ecwid_shop_teaser_query_args`,
`ran_ecwid_shop_teaser_product_url`, `ran_ecwid_shop_teaser_product_card`, and
`ran_ecwid_shop_teaser_static_fallback_products`. Fallback cards must supply
an ID, name, price, image URL and alt text, destination URL, and stock state.

## Accessibility and security

Product images require meaningful alternative text, and unavailable products
must preserve their visible state. Category IDs are scoped to their resolved
Ecwid store. Do not expose Ecwid API tokens in public markup or logs; public
fallbacks must not reveal diagnostic details.

## Release lifecycle

`Quality` is the single qualification authority for pull requests, trusted pushes
to `main`, and the exact Release Please candidate branch. It runs the shared
WordPress-plugin baseline, repository source/generated checks, the WordPress
6.5 / PHP 8.0 compatibility floor, current WordPress / PHP 8.3 coverage,
Plugin Check, and fresh installation of the exact distributable ZIP.

The privileged `Release Please` publisher runs only after a successful
same-repository `Quality` run for an exact `main` revision. It authenticates
that triggering run, checks out the exact qualified commit without persisted
credentials, and lets the pinned Release Please action open/update the release
PR or publish a merged release. Release Please candidate PRs receive a
read-only full `Quality` run by explicit workflow dispatch.

When a release is created, the publisher downloads the exact ZIP, SHA-256 file,
and manifest produced by the triggering `Quality` run, proves that they belong
to the qualified commit/tag, attaches them to the GitHub Release, and reads back
the exact tag, release target, asset names, and SHA-256 digests.

The unpublished `1.2.3` proposal was superseded and has no tag or GitHub
Release. The next real publication is expected to be `v1.2.4`. WordPress.org
publication remains separate and disabled.

## License

RAN Ecwid Shop Teaser is licensed under the [GNU General Public License v2.0
or later](LICENSE) (`GPL-2.0-or-later`).

## Support and contributing

Report reproducible issues at
[RocketsAreNostalgic/ran-ecwid-shop-teaser](https://github.com/RocketsAreNostalgic/ran-ecwid-shop-teaser/issues).
Include the relevant lint and build output with changes.
