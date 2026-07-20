=== RAN Ecwid Shop Teaser ===
Contributors: rocketsarenostalgic
Tags: ecwid, products, shop, block, gutenberg
Requires at least: 6.5
Tested up to: 6.5
Requires PHP: 8.0
x-release-please-start-version
Stable tag: 1.2.1
x-release-please-end
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

Display a configurable Ecwid product grid with editor previews, caching, and theme-independent baseline styles.

== Description ==

RAN Ecwid Shop Teaser provides the `ran/ecwid-shop-teaser` dynamic block in the core Widgets category. Choose an Ecwid category and the block renders accessible product cards with a single product link per card.

The official Ecwid plugin is the default credential provider, but the plugin can instead receive a store ID, token, product URL, query, and fallback cards through documented WordPress filters. This lets a site use a companion plugin without hard-coding a theme dependency.

When Ecwid is unavailable, public visitors receive only cached or filter-provided fallback cards. Diagnostic messages remain limited to editors.

== Installation ==

1. Upload the complete plugin ZIP through **Plugins > Add New > Upload Plugin**, or install it in the normal WordPress plugins directory.
2. Activate **RAN Ecwid Shop Teaser**.
3. Configure the official Ecwid plugin, or provide credentials with the documented filters.
4. Add **Ecwid Shop Teaser** from the Widgets category and choose an Ecwid category ID.

== Frequently Asked Questions ==

= Does this require the Ecwid WordPress plugin? =

No. The Ecwid plugin is the default integration, but a companion plugin or site code can supply credentials and product cards through RAN Ecwid Shop Teaser filters.

= Does this plugin add shop pages or checkout? =

No. It renders product teaser cards that link to product URLs supplied by Ecwid or by the integration filter.

== External services ==

This plugin can connect to the [Ecwid REST API](https://api-docs.ecwid.com/reference/rest-api-v3) to retrieve product data. When configured, it sends the Ecwid store ID, API token, category ID, and product query to Ecwid from the WordPress server. The token is never sent to site visitors. The service is governed by [Ecwid's terms of service](https://www.ecwid.com/terms-of-service) and [privacy policy](https://www.ecwid.com/privacy-policy).

== Changelog ==

= 1.0.0 =

* First public release with WordPress 6.5 and PHP 8.0 support.
* Added portable block registration, accessible single-link product cards, and theme-preset fallbacks.
