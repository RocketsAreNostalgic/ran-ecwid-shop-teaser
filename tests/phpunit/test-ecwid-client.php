<?php
/**
 * Direct Ecwid client tests.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

use RAN\EcwidShopTeaser\Commerce\Ecwid\Client;

class RAN_Ecwid_Shop_Teaser_Ecwid_Client_Test extends WP_UnitTestCase {
	/**
	 * Force missing credentials without relying on an installed Ecwid plugin.
	 *
	 * @return int
	 */
	public function missing_store_id() {
		return 0;
	}

	/**
	 * Force missing credentials without relying on an installed Ecwid plugin.
	 *
	 * @return string
	 */
	public function missing_token() {
		return '';
	}

	/**
	 * Explain both supported credential sources before making a REST request.
	 *
	 * @return void
	 */
	public function test_missing_credentials_explains_both_supported_remedies() {
		add_filter( 'ran_ecwid_shop_teaser_store_id', array( $this, 'missing_store_id' ), PHP_INT_MAX );
		add_filter( 'ran_ecwid_shop_teaser_token', array( $this, 'missing_token' ), PHP_INT_MAX );

		$result = ( new Client() )->search_products( array() );

		remove_filter( 'ran_ecwid_shop_teaser_store_id', array( $this, 'missing_store_id' ), PHP_INT_MAX );
		remove_filter( 'ran_ecwid_shop_teaser_token', array( $this, 'missing_token' ), PHP_INT_MAX );

		$this->assertWPError( $result );
		$this->assertSame( 'ran_ecwid_shop_teaser_missing_credentials', $result->get_error_code() );
		$this->assertStringContainsString( 'Activate and configure the official Ecwid plugin', $result->get_error_message() );
		$this->assertStringContainsString( 'ran_ecwid_shop_teaser_store_id', $result->get_error_message() );
		$this->assertStringContainsString( 'ran_ecwid_shop_teaser_token', $result->get_error_message() );
	}
}
