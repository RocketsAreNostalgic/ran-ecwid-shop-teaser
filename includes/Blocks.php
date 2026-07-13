<?php
/**
 * Block registration for RAN Ecwid Shop Teaser.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Registers compiled block metadata, falling back to source before a first build.
 */
final class Blocks {
	/**
	 * Register all block metadata directories.
	 *
	 * @return void
	 */
	public static function register() {
		if ( ! function_exists( 'register_block_type' ) ) {
			return;
		}

		foreach ( self::block_directories() as $block_directory ) {
			register_block_type( $block_directory );
		}
	}

	/**
	 * Find directories containing block metadata beneath the preferred runtime root.
	 *
	 * @return string[]
	 */
	private static function block_directories() {
		$blocks_root = self::blocks_root();

		if ( ! is_dir( $blocks_root ) ) {
			return array();
		}

		$block_directories = array();
		$iterator          = new \RecursiveIteratorIterator(
			new \RecursiveDirectoryIterator(
				$blocks_root,
				\FilesystemIterator::SKIP_DOTS
			)
		);

		foreach ( $iterator as $file ) {
			if ( 'block.json' === $file->getFilename() ) {
				$block_directories[] = $file->getPath();
			}
		}

		sort( $block_directories );

		return $block_directories;
	}

	/**
	 * Resolve the compiled runtime tree when it is available.
	 *
	 * @return string
	 */
	private static function blocks_root() {
		$build_root = RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'build/blocks';

		if ( is_dir( $build_root ) ) {
			return $build_root;
		}

		return RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'blocks';
	}
}
