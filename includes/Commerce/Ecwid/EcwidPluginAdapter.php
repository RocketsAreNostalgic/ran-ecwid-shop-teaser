<?php
/**
 * Guarded adapter around the installed Ecwid plugin.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Ecwid;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Reads Ecwid data through the active Ecwid plugin when available.
 */
final class EcwidPluginAdapter {
	/**
	 * Get the configured Ecwid store ID.
	 *
	 * @return int
	 */
	public function get_store_id() {
		if ( function_exists( 'get_ecwid_store_id' ) ) {
			return absint( get_ecwid_store_id() );
		}

		return absint( get_option( 'ecwid_store_id' ) );
	}

	/**
	 * Get the configured Ecwid API token without exposing it.
	 *
	 * @return string
	 */
	public function get_token() {
		if ( class_exists( '\Ecwid_Api_V3' ) && is_callable( array( '\Ecwid_Api_V3', 'get_token' ) ) ) {
			$token = \Ecwid_Api_V3::get_token();

			if ( is_string( $token ) ) {
				return $token;
			}
		}

		return '';
	}

	/**
	 * Get the Ecwid plugin's current API status.
	 *
	 * @return string
	 */
	public function get_api_status() {
		if ( class_exists( '\Ecwid_Api_V3' ) && is_callable( array( '\Ecwid_Api_V3', 'get_api_status' ) ) ) {
			$status = \Ecwid_Api_V3::get_api_status();

			if ( is_string( $status ) && '' !== $status ) {
				return $status;
			}
		}

		return 'unknown';
	}

	/**
	 * Explain why the plugin-backed API is not currently usable.
	 *
	 * @return string
	 */
	public function get_api_status_message() {
		$store_id = $this->get_store_id();
		$token    = $this->get_token();
		$status   = $this->get_api_status();

		if ( 0 >= $store_id ) {
			return __( 'Ecwid store ID is missing.', 'ran-ecwid-shop-teaser' );
		}

		if ( '' === $token ) {
			return sprintf(
				/* translators: %s: Ecwid plugin API status code. */
				__( 'Ecwid API token is missing or invalid. Plugin status: %s.', 'ran-ecwid-shop-teaser' ),
				$status
			);
		}

		return sprintf(
			/* translators: %s: Ecwid plugin API status code. */
			__( 'Ecwid plugin did not return products. Plugin status: %s.', 'ran-ecwid-shop-teaser' ),
			$status
		);
	}

	/**
	 * Search products through the installed Ecwid plugin wrapper.
	 *
	 * @param array<string,mixed> $params Search parameters.
	 * @return object|false
	 */
	public function search_products( $params ) {
		if ( ! class_exists( '\Ecwid_Api_V3' ) ) {
			return false;
		}

		$api = new \Ecwid_Api_V3();

		if ( ! is_callable( array( $api, 'search_products' ) ) ) {
			return false;
		}

		return $api->search_products( $params );
	}

	/**
	 * Build a local storefront product URL.
	 *
	 * @param int $product_id Product ID.
	 * @return string
	 */
	public function get_product_url( $product_id ) {
		if ( class_exists( '\Ecwid_Store_Page' ) && is_callable( array( '\Ecwid_Store_Page', 'get_product_url_default_fallback' ) ) ) {
			return (string) \Ecwid_Store_Page::get_product_url_default_fallback( $product_id );
		}

		if ( class_exists( '\Ecwid_Store_Page' ) && is_callable( array( '\Ecwid_Store_Page', 'get_store_url' ) ) ) {
			return trailingslashit( (string) \Ecwid_Store_Page::get_store_url() ) . '#!/p/' . absint( $product_id );
		}

		return home_url( '/shop/#!/p/' . absint( $product_id ) );
	}
}
