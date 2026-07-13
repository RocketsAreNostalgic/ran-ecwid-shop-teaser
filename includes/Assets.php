<?php
/**
 * Asset URL helpers for RAN Ecwid Shop Teaser.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Preserves Local URLs through optimizer output for this block's generated assets.
 */
final class Assets {
	/**
	 * Register asset URL filters.
	 *
	 * @return void
	 */
	public static function register() {
		add_filter( 'script_loader_src', array( self::class, 'root_relative_src' ), 20, 2 );
		add_filter( 'style_loader_src', array( self::class, 'root_relative_src' ), 20, 2 );
		add_filter( 'js_do_concat', array( self::class, 'skip_concatenation' ), 20, 2 );
		add_filter( 'css_do_concat', array( self::class, 'skip_concatenation' ), 20, 2 );
	}

	/**
	 * Convert this plugin's absolute asset URL to a root-relative URL.
	 *
	 * @param string $src    Asset URL.
	 * @param string $handle Asset handle.
	 * @return string
	 */
	public static function root_relative_src( $src, $handle ) {
		if ( ! self::is_block_handle( $handle ) ) {
			return $src;
		}

		$path = wp_parse_url( $src, PHP_URL_PATH );

		if ( ! is_string( $path ) || false === strpos( $path, '/wp-content/plugins/ran-ecwid-shop-teaser/' ) ) {
			return $src;
		}

		$query = wp_parse_url( $src, PHP_URL_QUERY );

		return is_string( $query ) && '' !== $query ? $path . '?' . $query : $path;
	}

	/**
	 * Keep this block's assets out of optimizer concatenators.
	 *
	 * @param bool   $do_concat Whether the asset should be concatenated.
	 * @param string $handle    Asset handle.
	 * @return bool
	 */
	public static function skip_concatenation( $do_concat, $handle ) {
		return self::is_block_handle( $handle ) ? false : $do_concat;
	}

	/**
	 * Identify this block's generated WordPress asset handles.
	 *
	 * @param string $handle Asset handle.
	 * @return bool
	 */
	private static function is_block_handle( $handle ) {
		return 0 === strpos( $handle, 'ran-ecwid-shop-teaser' );
	}
}
