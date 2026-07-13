<?php
/**
 * Render callback for ran/ecwid-shop-teaser.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

echo \RAN\EcwidShopTeaser\Commerce\Rendering\EcwidProductGrid::render( $attributes );
