<?php
/**
 * REST endpoints for Ecwid product-grid tooling.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Ecwid;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Registers editor-only REST helpers for Ecwid product grids.
 */
final class RestController {
	const REST_NAMESPACE = 'ran-ecwid-shop-teaser/v1';

	/**
	 * Register REST routes.
	 *
	 * @return void
	 */
	public static function register() {
		register_rest_route(
			self::REST_NAMESPACE,
			'/ecwid-shop-teaser/preview',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( self::class, 'preview_product_grid' ),
				'permission_callback' => array( self::class, 'can_refresh' ),
				'args'                => self::route_args(),
			)
		);

		register_rest_route(
			self::REST_NAMESPACE,
			'/ecwid-shop-teaser/refresh',
			array(
				'methods'             => \WP_REST_Server::CREATABLE,
				'callback'            => array( self::class, 'refresh_product_grid' ),
				'permission_callback' => array( self::class, 'can_refresh' ),
				'args'                => self::route_args(),
			)
		);
	}

	/**
	 * Get shared route argument schema.
	 *
	 * @return array<string,array<string,mixed>>
	 */
	private static function route_args() {
		return array(
			'categoryId'            => array(
				'type'              => 'integer',
				'required'          => true,
				'sanitize_callback' => 'absint',
			),
			'limit'                 => array(
				'type'              => 'integer',
				'default'           => 12,
				'sanitize_callback' => 'absint',
			),
			'showUnavailable'       => array(
				'type'    => 'boolean',
				'default' => false,
			),
			'cacheTtl'              => array(
				'type'              => 'integer',
				'default'           => 300,
				'sanitize_callback' => 'absint',
			),
			'staticFallbackEnabled' => array(
				'type'    => 'boolean',
				'default' => true,
			),
		);
	}

	/**
	 * Check whether the current user can refresh product-grid caches.
	 *
	 * @return bool
	 */
	public static function can_refresh() {
		return current_user_can( 'edit_posts' );
	}

	/**
	 * Read product cards for editor preview without clearing volatile cache.
	 *
	 * @param \WP_REST_Request $request REST request.
	 * @return \WP_REST_Response
	 */
	public static function preview_product_grid( $request ) {
		$repository = new ProductRepository();
		$result     = $repository->get_product_cards( self::attributes_from_request( $request ) );

		return self::response_from_result( $result );
	}

	/**
	 * Refresh product cards for one grid configuration.
	 *
	 * @param \WP_REST_Request $request REST request.
	 * @return \WP_REST_Response
	 */
	public static function refresh_product_grid( $request ) {
		$repository = new ProductRepository();
		$result     = $repository->refresh_product_cards( self::attributes_from_request( $request ) );

		return self::response_from_result( $result );
	}

	/**
	 * Build normalized block attributes from a REST request.
	 *
	 * @param \WP_REST_Request $request REST request.
	 * @return array<string,mixed>
	 */
	private static function attributes_from_request( $request ) {
		return array(
			'categoryId'            => $request->get_param( 'categoryId' ),
			'limit'                 => $request->get_param( 'limit' ),
			'showUnavailable'       => $request->get_param( 'showUnavailable' ),
			'cacheTtl'              => $request->get_param( 'cacheTtl' ),
			'staticFallbackEnabled' => $request->get_param( 'staticFallbackEnabled' ),
		);
	}

	/**
	 * Build a REST response from a product repository result.
	 *
	 * @param array{products:array<int,array<string,mixed>>,source:string,message:string} $result Repository result.
	 * @return \WP_REST_Response
	 */
	private static function response_from_result( $result ) {
		return rest_ensure_response(
			array(
				'count'    => count( $result['products'] ),
				'source'   => $result['source'],
				'message'  => $result['message'],
				'products' => array_map( array( self::class, 'serialize_product' ), $result['products'] ),
			)
		);
	}

	/**
	 * Serialize a product card for editor preview.
	 *
	 * @param array<string,mixed> $product Product card.
	 * @return array<string,mixed>
	 */
	private static function serialize_product( $product ) {
		return array(
			'id'        => absint( $product['id'] ?? 0 ),
			'name'      => sanitize_text_field( (string) ( $product['name'] ?? '' ) ),
			'price'     => sanitize_text_field( (string) ( $product['price'] ?? '' ) ),
			'image_url' => esc_url_raw( (string) ( $product['image_url'] ?? '' ) ),
			'image_alt' => sanitize_text_field( (string) ( $product['image_alt'] ?? '' ) ),
			'url'       => esc_url_raw( (string) ( $product['url'] ?? '' ) ),
		);
	}
}
