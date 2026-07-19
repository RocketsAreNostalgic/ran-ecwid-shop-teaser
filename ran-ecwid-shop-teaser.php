<?php
/**
 * Plugin Name: RAN Ecwid Shop Teaser
 * Plugin URI: https://github.com/RocketsAreNostalgic/ran-ecwid-shop-teaser
 * Description: A dynamic Ecwid product-grid block with editor previews, caching, and theme-independent baseline styling.
 * x-release-please-start-version
 * Version: 1.1.1
 * x-release-please-end
 * Author: RAN
 * Author URI: https://github.com/RocketsAreNostalgic/
 * Text Domain: ran-ecwid-shop-teaser
 * Domain Path: /languages
 * Requires at least: 6.5
 * Requires PHP: 8.0
 * License: GPL-2.0-or-later
 * License URI: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'RAN_ECWID_SHOP_TEASER_VERSION', '1.1.1' ); // x-release-please-version
define( 'RAN_ECWID_SHOP_TEASER_PLUGIN_FILE', __FILE__ );
define( 'RAN_ECWID_SHOP_TEASER_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'RAN_ECWID_SHOP_TEASER_PLUGIN_URL', plugin_dir_url( __FILE__ ) );

require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Blocks.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Ecwid/EcwidPluginAdapter.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Ecwid/Credentials.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Ecwid/Client.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Ecwid/ProductRepository.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Ecwid/RestController.php';
require_once RAN_ECWID_SHOP_TEASER_PLUGIN_DIR . 'includes/Commerce/Rendering/EcwidProductGrid.php';

add_action( 'init', array( \RAN\EcwidShopTeaser\Blocks::class, 'register' ) );
add_action( 'rest_api_init', array( \RAN\EcwidShopTeaser\Commerce\Ecwid\RestController::class, 'register' ) );
