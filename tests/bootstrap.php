<?php
/**
 * WordPress integration-test bootstrap.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

$_tests_dir = getenv( 'WP_TESTS_DIR' );
$autoload   = dirname( __DIR__ ) . '/vendor/autoload.php';

if ( ! $_tests_dir ) {
	$_tests_dir = '/tmp/wordpress-tests-lib';
}

if ( ! file_exists( $_tests_dir . '/includes/functions.php' ) ) {
	fwrite( STDERR, "WordPress test library not found. Set WP_TESTS_DIR before running PHPUnit.\n" );
	exit( 1 );
}

if ( file_exists( $autoload ) ) {
	require_once $autoload;
}

if ( ! defined( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH' ) ) {
	define( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH', dirname( __DIR__ ) . '/vendor/yoast/phpunit-polyfills' );
}

require_once $_tests_dir . '/includes/functions.php';

tests_add_filter(
	'muplugins_loaded',
	static function () {
		require dirname( __DIR__ ) . '/ran-ecwid-shop-teaser.php';
	}
);

require $_tests_dir . '/includes/bootstrap.php';
