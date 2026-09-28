<?php
/**
 * Render callback for ran/ecwid-shop-teaser.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** @var array<string, mixed> $attributes Block attributes supplied by WordPress render context. */

// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- The renderer escapes dynamic values and returns complete block markup.
echo \RAN\EcwidShopTeaser\Commerce\Rendering\EcwidProductGrid::render( $attributes );
