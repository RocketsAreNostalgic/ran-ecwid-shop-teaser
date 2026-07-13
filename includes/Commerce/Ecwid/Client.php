<?php
/**
 * Direct Ecwid REST client.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Ecwid;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Minimal direct REST client for Ecwid catalog reads.
 */
final class Client {
	/**
	 * Credentials.
	 *
	 * @var Credentials
	 */
	private $credentials;

	/**
	 * Constructor.
	 *
	 * @param Credentials|null $credentials Credentials.
	 */
	public function __construct( $credentials = null ) {
		$this->credentials = $credentials instanceof Credentials ? $credentials : new Credentials();
	}

	/**
	 * Search products.
	 *
	 * @param array<string,mixed> $params Search parameters.
	 * @return object|\WP_Error
	 */
	public function search_products( $params ) {
		$store_id = $this->credentials->get_store_id();
		$token    = $this->credentials->get_token();

		if ( 0 >= $store_id || '' === $token ) {
			return new \WP_Error( 'ran_ecwid_shop_teaser_missing_credentials', __( 'Ecwid credentials are unavailable.', 'ran-ecwid-shop-teaser' ) );
		}

		$url = add_query_arg(
			array_filter(
				$params,
				static function ( $value ) {
					return null !== $value && '' !== $value;
				}
			),
			sprintf(
				'https://app.ecwid.com/api/v3/%d/products',
				$store_id
			)
		);

		$response = wp_remote_get(
			$url,
			array(
				'headers' => array(
					'Authorization' => 'Bearer ' . $token,
					'Accept'        => 'application/json',
				),
				'timeout' => 10,
			)
		);

		if ( is_wp_error( $response ) ) {
			return $response;
		}

		$status_code = wp_remote_retrieve_response_code( $response );

		if ( 200 !== $status_code ) {
			return new \WP_Error(
				'ran_ecwid_shop_teaser_bad_response',
				__( 'Ecwid returned an unexpected response.', 'ran-ecwid-shop-teaser' ),
				array( 'status' => $status_code )
			);
		}

		$data = json_decode( wp_remote_retrieve_body( $response ) );

		if ( ! is_object( $data ) ) {
			return new \WP_Error( 'ran_ecwid_shop_teaser_bad_json', __( 'Ecwid returned invalid JSON.', 'ran-ecwid-shop-teaser' ) );
		}

		return $data;
	}
}
