<?php
/**
 * Normalized Ecwid product repository.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Ecwid;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Fetches, caches, normalizes, and falls back product-card data.
 */
final class ProductRepository {
	const RESPONSE_FIELDS = 'items(id,name,enabled,inStock,defaultDisplayedPriceFormatted,imageUrl,thumbnailUrl,media,url),total,count,offset,limit';

	/**
	 * Ecwid plugin adapter.
	 *
	 * @var EcwidPluginAdapter
	 */
	private $adapter;

	/**
	 * Direct REST client.
	 *
	 * @var Client
	 */
	private $client;

	/**
	 * Last fetch failure reason.
	 *
	 * @var string
	 */
	private $last_error_message = '';

	/**
	 * Constructor.
	 *
	 * @param EcwidPluginAdapter|null $adapter Ecwid plugin adapter.
	 * @param Client|null             $client Direct REST client.
	 */
	public function __construct( $adapter = null, $client = null ) {
		$this->adapter = $adapter instanceof EcwidPluginAdapter ? $adapter : new EcwidPluginAdapter();
		$this->client  = $client instanceof Client ? $client : new Client( new Credentials( $this->adapter ) );
	}

	/**
	 * Get product cards for block attributes.
	 *
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return array{products:array<int,array<string,mixed>>,source:string,message:string}
	 */
	public function get_product_cards( $attributes ) {
		$query = $this->query_from_attributes( $attributes );

		if ( 0 >= $query['category'] ) {
			return array(
				'products' => array(),
				'source'   => 'missing-category',
				'message'  => __( 'Choose an Ecwid category before publishing this product grid.', 'ran-ecwid-shop-teaser' ),
			);
		}

		$fresh_key    = $this->fresh_cache_key( $query );
		$last_good_key = $this->last_good_cache_key( $query );
		$fresh        = get_transient( $fresh_key );

		if ( is_array( $fresh ) ) {
			return array(
				'products' => $fresh,
				'source'   => 'fresh-cache',
				'message'  => '',
			);
		}

		$cached_failure = get_transient( $this->negative_cache_key( $query ) );

		if ( false !== $cached_failure ) {
			$message = is_string( $cached_failure ) && '' !== $cached_failure
				? $cached_failure
				: __( 'Ecwid is temporarily unavailable.', 'ran-ecwid-shop-teaser' );

			return $this->fallback_response( $query, $message, $attributes );
		}

		$products = $this->fetch_product_cards( $query );

		if ( is_array( $products ) && ! empty( $products ) ) {
			$ttl = max( 60, absint( $attributes['cacheTtl'] ?? 300 ) );
			set_transient( $fresh_key, $products, $ttl );
			set_transient( $last_good_key, $products, WEEK_IN_SECONDS );

			return array(
				'products' => $products,
				'source'   => 'ecwid',
				'message'  => '',
			);
		}

		$message = '' !== $this->last_error_message
			? $this->last_error_message
			: __( 'Ecwid product data could not be loaded.', 'ran-ecwid-shop-teaser' );

		set_transient( $this->negative_cache_key( $query ), $message, 2 * MINUTE_IN_SECONDS );
		$this->maybe_log_fallback_message( $query, $message );

		return $this->fallback_response( $query, $message, $attributes );
	}

	/**
	 * Clear volatile cache for this query and fetch fresh product cards.
	 *
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return array{products:array<int,array<string,mixed>>,source:string,message:string}
	 */
	public function refresh_product_cards( $attributes ) {
		$query = $this->query_from_attributes( $attributes );

		if ( 0 >= $query['category'] ) {
			return array(
				'products' => array(),
				'source'   => 'missing-category',
				'message'  => __( 'Choose an Ecwid category before refreshing this product grid.', 'ran-ecwid-shop-teaser' ),
			);
		}

		$fresh_key     = $this->fresh_cache_key( $query );
		$last_good_key = $this->last_good_cache_key( $query );

		delete_transient( $fresh_key );
		delete_transient( $this->negative_cache_key( $query ) );

		$products = $this->fetch_product_cards( $query );

		if ( is_array( $products ) && ! empty( $products ) ) {
			$ttl = max( 60, absint( $attributes['cacheTtl'] ?? 300 ) );
			set_transient( $fresh_key, $products, $ttl );
			set_transient( $last_good_key, $products, WEEK_IN_SECONDS );

			return array(
				'products' => $products,
				'source'   => 'ecwid',
				'message'  => '',
			);
		}

		$message = '' !== $this->last_error_message
			? $this->last_error_message
			: __( 'Ecwid product data could not be loaded.', 'ran-ecwid-shop-teaser' );

		set_transient( $this->negative_cache_key( $query ), $message, 2 * MINUTE_IN_SECONDS );
		$this->maybe_log_fallback_message( $query, $message );

		return $this->fallback_response( $query, $message, $attributes );
	}

	/**
	 * Build a normalized query.
	 *
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return array<string,mixed>
	 */
	private function query_from_attributes( $attributes ) {
		$show_unavailable = ! empty( $attributes['showUnavailable'] );
		$credentials      = new Credentials( $this->adapter );

		$query = array(
			'store_id'         => $credentials->get_store_id(),
			'category'         => absint( $attributes['categoryId'] ?? 0 ),
			'limit'            => min( 24, max( 1, absint( $attributes['limit'] ?? 12 ) ) ),
			'show_unavailable' => $show_unavailable,
		);

		/**
		 * Filters the normalized Ecwid product query for a product grid.
		 *
		 * The category ID is scoped to the resolved Ecwid store ID. The returned
		 * array is normalized again before cache keys or API requests are built.
		 *
		 * @param array<string,mixed> $query Normalized query.
		 * @param array<string,mixed> $attributes Block attributes.
		 */
		$filtered_query = apply_filters( 'ran_ecwid_shop_teaser_query_args', $query, $attributes );

		if ( ! is_array( $filtered_query ) ) {
			return $query;
		}

		return array(
			'store_id'         => absint( $filtered_query['store_id'] ?? $query['store_id'] ),
			'category'         => absint( $filtered_query['category'] ?? $query['category'] ),
			'limit'            => min( 24, max( 1, absint( $filtered_query['limit'] ?? $query['limit'] ) ) ),
			'show_unavailable' => array_key_exists( 'show_unavailable', $filtered_query ) ? ! empty( $filtered_query['show_unavailable'] ) : $query['show_unavailable'],
		);
	}

	/**
	 * Fetch cards through the plugin adapter first, then direct REST.
	 *
	 * @param array<string,mixed> $query Query.
	 * @return array<int,array<string,mixed>>|false
	 */
	private function fetch_product_cards( $query ) {
		$this->last_error_message = '';

		$params = $this->request_params( $query, false );
		$result = $this->adapter->search_products( $params );
		$cards  = $this->normalize_result( $result, $query );

		if ( ! empty( $cards ) ) {
			return $cards;
		}

		$this->last_error_message = $this->adapter->get_api_status_message();

		$result = $this->client->search_products( $this->request_params( $query, true ) );

		if ( is_wp_error( $result ) ) {
			$this->last_error_message = $this->format_wp_error_message( $result );
			return false;
		}

		$cards = $this->normalize_result( $result, $query );

		if ( empty( $cards ) && '' === $this->last_error_message ) {
			$this->last_error_message = __( 'Ecwid returned no matching products for this category.', 'ran-ecwid-shop-teaser' );
		}

		return ! empty( $cards ) ? $cards : false;
	}

	/**
	 * Format a safe error message for editor-only debug output.
	 *
	 * @param \WP_Error $error Error object.
	 * @return string
	 */
	private function format_wp_error_message( $error ) {
		$data        = $error->get_error_data();
		$status_code = is_array( $data ) && isset( $data['status'] ) ? absint( $data['status'] ) : 0;
		$message     = $error->get_error_message();

		if ( 0 < $status_code ) {
			return sprintf(
				/* translators: 1: HTTP status code. 2: Error message. */
				__( 'Direct Ecwid REST request failed with HTTP %1$d: %2$s', 'ran-ecwid-shop-teaser' ),
				$status_code,
				$message
			);
		}

		return sprintf(
			/* translators: %s: Error message. */
			__( 'Direct Ecwid REST request failed: %s', 'ran-ecwid-shop-teaser' ),
			$message
		);
	}

	/**
	 * Log fallback details in local/debug environments without surfacing PHP warnings.
	 *
	 * @param array<string,mixed> $query Query.
	 * @param string              $message Failure message.
	 * @return void
	 */
	private function maybe_log_fallback_message( $query, $message ) {
		if ( ! defined( 'WP_DEBUG_LOG' ) || ! WP_DEBUG_LOG || '' === $message ) {
			return;
		}

		error_log( // phpcs:ignore WordPress.PHP.DevelopmentFunctions.error_log_error_log
			sprintf(
				'[ran-ecwid-shop-teaser] Ecwid product grid fallback for store %d, category %d, limit %d: %s',
				absint( $query['store_id'] ?? 0 ),
				absint( $query['category'] ?? 0 ),
				absint( $query['limit'] ?? 0 ),
				$message
			)
		);
	}

	/**
	 * Build Ecwid API search params.
	 *
	 * @param array<string,mixed> $query Query.
	 * @param bool                $include_response_fields Include responseFields.
	 * @return array<string,mixed>
	 */
	private function request_params( $query, $include_response_fields ) {
		$params = array(
			'category' => $query['category'],
			'limit'    => $query['limit'],
		);

		if ( empty( $query['show_unavailable'] ) ) {
			$params['enabled'] = 'true';
			$params['inStock'] = 'true';
		}

		if ( $include_response_fields ) {
			$params['responseFields'] = self::RESPONSE_FIELDS;
		}

		return $params;
	}

	/**
	 * Normalize an Ecwid API response.
	 *
	 * @param object|false|null   $result API result.
	 * @param array<string,mixed> $query Query.
	 * @return array<int,array<string,mixed>>
	 */
	private function normalize_result( $result, $query ) {
		if ( ! is_object( $result ) || empty( $result->items ) || ! is_array( $result->items ) ) {
			return array();
		}

		$cards = array();

		foreach ( $result->items as $item ) {
			$card = $this->normalize_product( $item, $query );

			if ( ! empty( $card ) ) {
				$cards[] = $card;
			}
		}

		return $cards;
	}

	/**
	 * Normalize one product.
	 *
	 * @param object              $product Product object.
	 * @param array<string,mixed> $query Query.
	 * @return array<string,mixed>
	 */
	private function normalize_product( $product, $query ) {
		$id       = absint( $product->id ?? 0 );
		$name     = isset( $product->name ) ? trim( (string) $product->name ) : '';
		$enabled  = ! isset( $product->enabled ) || (bool) $product->enabled;
		$in_stock = ! isset( $product->inStock ) || (bool) $product->inStock;

		if ( 0 >= $id || '' === $name ) {
			return array();
		}

		if ( empty( $query['show_unavailable'] ) && ( ! $enabled || ! $in_stock ) ) {
			return array();
		}

		$image_url = $this->get_product_image_url( $product );
		$url       = isset( $product->url ) ? (string) $product->url : '';

		if ( '' === $url ) {
			$url = $this->adapter->get_product_url( $id );
		}

		/**
		 * Filters a product URL before it is used in product-card data.
		 *
		 * @param string              $url Product URL.
		 * @param int                 $id Ecwid product ID.
		 * @param object              $product Raw Ecwid product object.
		 * @param array<string,mixed> $query Normalized query.
		 */
		$url = apply_filters( 'ran_ecwid_shop_teaser_product_url', $url, $id, $product, $query );
		$url = is_string( $url ) ? esc_url_raw( $url ) : '';

		if ( '' === $url || '' === $image_url ) {
			return array();
		}

		$card = array(
			'id'        => $id,
			'name'      => $name,
			'price'     => isset( $product->defaultDisplayedPriceFormatted ) ? (string) $product->defaultDisplayedPriceFormatted : '',
			'image_url' => $image_url,
			'image_alt' => $this->get_product_image_alt( $product, $name ),
			'url'       => $url,
			'enabled'   => $enabled,
			'in_stock'  => $in_stock,
		);

		/**
		 * Filters normalized product-card data before it is cached or rendered.
		 *
		 * Return an empty value to remove the product from the grid.
		 *
		 * @param array<string,mixed> $card Normalized card data.
		 * @param object              $product Raw Ecwid product object.
		 * @param array<string,mixed> $query Normalized query.
		 */
		$card = apply_filters( 'ran_ecwid_shop_teaser_product_card', $card, $product, $query );

		return $this->normalize_product_card( $card );
	}

	/**
	 * Get product image URL.
	 *
	 * @param object $product Product object.
	 * @return string
	 */
	private function get_product_image_url( $product ) {
		foreach ( array( 'imageUrl', 'thumbnailUrl', 'originalImageUrl' ) as $field ) {
			if ( ! empty( $product->{$field} ) && is_string( $product->{$field} ) ) {
				return $product->{$field};
			}
		}

		if ( ! empty( $product->media->images ) && is_array( $product->media->images ) ) {
			foreach ( $product->media->images as $image ) {
				foreach ( array( 'imageOriginalUrl', 'imageUrl', 'thumbnailUrl' ) as $field ) {
					if ( ! empty( $image->{$field} ) && is_string( $image->{$field} ) ) {
						return $image->{$field};
					}
				}
			}
		}

		return '';
	}

	/**
	 * Get product image alt text.
	 *
	 * @param object $product Product object.
	 * @param string $fallback Fallback name.
	 * @return string
	 */
	private function get_product_image_alt( $product, $fallback ) {
		if ( ! empty( $product->media->images ) && is_array( $product->media->images ) ) {
			foreach ( $product->media->images as $image ) {
				if ( ! empty( $image->alt ) && is_string( $image->alt ) ) {
					return $image->alt;
				}
			}
		}

		return $fallback;
	}

	/**
	 * Return last-good or static fallback products.
	 *
	 * @param array<string,mixed> $query Query.
	 * @param string              $message Message.
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return array{products:array<int,array<string,mixed>>,source:string,message:string}
	 */
	private function fallback_response( $query, $message, $attributes ) {
		$last_good = get_transient( $this->last_good_cache_key( $query ) );

		if ( is_array( $last_good ) && ! empty( $last_good ) ) {
			return array(
				'products' => $last_good,
				'source'   => 'last-good-cache',
				'message'  => $message,
			);
		}

		if ( isset( $attributes['staticFallbackEnabled'] ) && false === $attributes['staticFallbackEnabled'] ) {
			return array(
				'products' => array(),
				'source'   => 'fallback-disabled',
				'message'  => $message,
			);
		}

		$fallback_products = $this->static_fallback_products( $query, $attributes );

		if ( empty( $fallback_products ) ) {
			return array(
				'products' => array(),
				'source'   => 'fallback-empty',
				'message'  => $message,
			);
		}

		return array(
			'products' => $fallback_products,
			'source'   => 'filter-fallback',
			'message'  => $message,
		);
	}

	/**
	 * Return filter-provided fallback products.
	 *
	 * @param array<string,mixed> $query Query.
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return array<int,array<string,mixed>>
	 */
	private function static_fallback_products( $query, $attributes ) {
		/**
		 * Filters fallback products used when live Ecwid data and last-good
		 * cache are unavailable.
		 *
		 * Generic plugin runtime provides no site-specific products. Themes or
		 * companion plugins can return product-card arrays with id, name, price,
		 * image_url, image_alt, url, enabled, and in_stock keys.
		 *
		 * @param array<int,array<string,mixed>> $products Fallback products.
		 * @param array<string,mixed>            $query Normalized query.
		 * @param array<string,mixed>            $attributes Block attributes.
		 */
		$products = apply_filters( 'ran_ecwid_shop_teaser_static_fallback_products', array(), $query, $attributes );

		return $this->normalize_product_cards( $products );
	}

	/**
	 * Normalize product-card arrays supplied by filters.
	 *
	 * @param mixed $products Product-card data.
	 * @return array<int,array<string,mixed>>
	 */
	private function normalize_product_cards( $products ) {
		if ( ! is_array( $products ) ) {
			return array();
		}

		$normalized = array();

		foreach ( $products as $product ) {
			$card = $this->normalize_product_card( $product );

			if ( ! empty( $card ) ) {
				$normalized[] = $card;
			}
		}

		return $normalized;
	}

	/**
	 * Normalize a product-card array supplied by Ecwid or a filter.
	 *
	 * @param mixed $product Product-card data.
	 * @return array<string,mixed>
	 */
	private function normalize_product_card( $product ) {
		if ( ! is_array( $product ) ) {
			return array();
		}

		$name      = sanitize_text_field( (string) ( $product['name'] ?? '' ) );
		$image_url = esc_url_raw( (string) ( $product['image_url'] ?? '' ) );
		$url       = esc_url_raw( (string) ( $product['url'] ?? '' ) );

		if ( '' === $name || '' === $image_url || '' === $url ) {
			return array();
		}

		$image_alt = sanitize_text_field( (string) ( $product['image_alt'] ?? '' ) );

		if ( '' === $image_alt ) {
			$image_alt = $name;
		}

		return array(
			'id'        => absint( $product['id'] ?? 0 ),
			'name'      => $name,
			'price'     => sanitize_text_field( (string) ( $product['price'] ?? '' ) ),
			'image_url' => $image_url,
			'image_alt' => $image_alt,
			'url'       => $url,
			'enabled'   => ! isset( $product['enabled'] ) || (bool) $product['enabled'],
			'in_stock'  => ! isset( $product['in_stock'] ) || (bool) $product['in_stock'],
		);
	}

	/**
	 * Fresh cache key.
	 *
	 * @param array<string,mixed> $query Query.
	 * @return string
	 */
	private function fresh_cache_key( $query ) {
		return 'ran_ecwid_shop_teaser_' . md5( wp_json_encode( $query ) );
	}

	/**
	 * Last-good cache key.
	 *
	 * @param array<string,mixed> $query Query.
	 * @return string
	 */
	private function last_good_cache_key( $query ) {
		return 'ran_ecwid_shop_teaser_last_' . md5( wp_json_encode( array( $query['store_id'], $query['category'], $query['limit'], $query['show_unavailable'] ) ) );
	}

	/**
	 * Negative cache key.
	 *
	 * @param array<string,mixed> $query Query.
	 * @return string
	 */
	private function negative_cache_key( $query ) {
		return 'ran_ecwid_shop_teaser_fail_' . md5( wp_json_encode( $query ) );
	}
}
