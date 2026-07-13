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
 * Registers compiled block metadata.
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

		$block_directory = self::block_directory();

		if ( '' === $block_directory ) {
			self::register_missing_build_notice();
			return;
		}

		register_block_type( $block_directory );
	}

	/**
	 * Return the compiled block directory when all metadata-referenced runtime
	 * assets are present.
	 *
	 * Source files intentionally are not a runtime fallback: block metadata refers
	 * to bundled scripts and generated styles that only exist after a build.
	 *
	 * @return string
	 */
	private static function block_directory() {
		$block_directory = RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'build/blocks/ecwid-shop-teaser';
		$required_files  = array(
			'block.json',
			'index.js',
			'index.asset.php',
			'index.css',
			'style-index.css',
			'render.php',
		);

		foreach ( $required_files as $required_file ) {
			if ( ! is_readable( $block_directory . '/' . $required_file ) ) {
				return '';
			}
		}

		return $block_directory;
	}

	/**
	 * Show an actionable, administrator-only notice when a deployment omits the
	 * committed build directory.
	 *
	 * @return void
	 */
	private static function register_missing_build_notice() {
		if ( ! is_admin() || ! current_user_can( 'activate_plugins' ) ) {
			return;
		}

		add_action( 'admin_notices', array( self::class, 'render_missing_build_notice' ) );
	}

	/**
	 * Render the missing build recovery notice.
	 *
	 * @return void
	 */
	public static function render_missing_build_notice() {
		?>
		<div class="notice notice-error">
			<p><?php esc_html_e( 'RAN Ecwid Shop Teaser could not register because its compiled build assets are missing. Reinstall the complete plugin package, including build/blocks/.', 'ran-ecwid-shop-teaser' ); ?></p>
		</div>
		<?php
	}
}
