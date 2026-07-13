<?php
/**
 * Product-grid renderer.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Rendering;

use RAN\EcwidShopTeaser\Commerce\Ecwid\ProductRepository;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Renders stable product-card markup for the Ecwid product grid.
 */
final class EcwidProductGrid {
	/**
	 * Render the block.
	 *
	 * @param array<string,mixed> $attributes Block attributes.
	 * @return string
	 */
	public static function render( $attributes ) {
		$attributes = self::normalize_attributes( $attributes );
		$repository = new ProductRepository();
		$result     = $repository->get_product_cards( $attributes );
		$products   = $result['products'];
		$source     = $result['source'];
		$message    = $result['message'];

		if ( empty( $products ) ) {
			return self::render_empty_state( $message );
		}

		$classes = array( 'ran-ecwid-shop-teaser' );

		if ( ! empty( $attributes['className'] ) ) {
			$classes[] = sanitize_html_class( $attributes['className'] );
		}

		$wrapper_attributes = get_block_wrapper_attributes(
			array(
				'class'            => implode( ' ', array_filter( $classes ) ),
				'style'            => self::get_presentation_style( $attributes ),
				'data-source'      => $source,
				'data-category-id' => (string) $attributes['categoryId'],
			)
		);

		ob_start();
		?>
		<div <?php echo $wrapper_attributes; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- get_block_wrapper_attributes() returns escaped attributes. ?>>
			<?php foreach ( $products as $product ) : ?>
				<?php
				$is_available    = ! empty( $product['enabled'] ) && ! empty( $product['in_stock'] );
				$product_classes = array( 'ran-ecwid-shop-teaser-card' );

				if ( ! $is_available ) {
					$product_classes[] = 'ran-ecwid-shop-teaser-card--unavailable';
				}
				?>
				<article class="<?php echo esc_attr( implode( ' ', $product_classes ) ); ?>">
					<a class="ran-ecwid-shop-teaser-card__link" href="<?php echo esc_url( $product['url'] ); ?>" aria-label="<?php
						/* translators: %s: Product name. */
						echo esc_attr( sprintf( __( 'View %s', 'ran-ecwid-shop-teaser' ), $product['name'] ) );
						?>">
						<span class="ran-ecwid-shop-teaser-card__media">
							<img
								src="<?php echo esc_url( $product['image_url'] ); ?>"
								alt="<?php echo esc_attr( $product['image_alt'] ); ?>"
								loading="lazy"
							/>
						</span>
						<h3 class="ran-ecwid-shop-teaser-card__title"><?php echo esc_html( $product['name'] ); ?></h3>
						<?php if ( '' !== $product['price'] ) : ?>
							<p class="ran-ecwid-shop-teaser-card__price"><?php echo esc_html( $product['price'] ); ?></p>
						<?php endif; ?>
						<?php if ( ! $is_available ) : ?>
							<p class="ran-ecwid-shop-teaser-card__availability"><?php esc_html_e( 'Unavailable', 'ran-ecwid-shop-teaser' ); ?></p>
						<?php endif; ?>
					</a>
				</article>
			<?php endforeach; ?>
			<?php if ( self::should_render_debug_notice( $message ) ) : ?>
				<p class="ran-ecwid-shop-teaser__notice"><?php echo esc_html( $message ); ?></p>
			<?php endif; ?>
		</div>
		<?php
		return (string) ob_get_clean();
	}

	/**
	 * Normalize attributes.
	 *
	 * @param array<string,mixed> $attributes Raw attributes.
	 * @return array<string,mixed>
	 */
	private static function normalize_attributes( $attributes ) {
		return array(
			'sourceMode'            => 'category',
			'categoryId'            => absint( $attributes['categoryId'] ?? 0 ),
			'limit'                 => min( 24, max( 1, absint( $attributes['limit'] ?? 12 ) ) ),
			'showUnavailable'       => ! empty( $attributes['showUnavailable'] ),
			'cacheTtl'              => max( 60, absint( $attributes['cacheTtl'] ?? 300 ) ),
			'fallbackMode'          => sanitize_key( $attributes['fallbackMode'] ?? 'last-good-cache-static' ),
			'staticFallbackEnabled' => ! isset( $attributes['staticFallbackEnabled'] ) || false !== $attributes['staticFallbackEnabled'],
			'className'             => isset( $attributes['className'] ) ? (string) $attributes['className'] : '',
			'style'                 => isset( $attributes['style'] ) && is_array( $attributes['style'] ) ? $attributes['style'] : array(),
			'gridGap'               => self::normalize_float( $attributes['gridGap'] ?? 1.5, 1.5, 0, 4 ),
			'imageAspectRatio'      => self::allowlisted_value( $attributes['imageAspectRatio'] ?? '3 / 2', array( '3 / 2', '1 / 1', '4 / 5' ), '3 / 2' ),
			'imageFit'              => self::allowlisted_value( $attributes['imageFit'] ?? 'cover', array( 'cover', 'contain' ), 'cover' ),
			'imageShape'            => self::allowlisted_value( $attributes['imageShape'] ?? 'square', array( 'square', 'soft', 'round' ), 'square' ),
			'imageWidth'            => self::normalize_float( $attributes['imageWidth'] ?? 18, 18, 0, 100 ),
			'imageWidthValue'       => self::spacing_value( $attributes['imageWidthValue'] ?? '18rem' ),
			'textAlign'             => self::allowlisted_value( $attributes['textAlign'] ?? 'center', array( 'left', 'center', 'right' ), 'center' ),
			'textColor'             => self::normalize_css_color( $attributes['textColor'] ?? '' ),
			'titleColor'            => self::normalize_css_color( $attributes['titleColor'] ?? '' ),
			'descriptionColor'      => self::normalize_css_color( $attributes['descriptionColor'] ?? '' ),
			'titleSize'             => self::font_size_slug( $attributes['titleSize'] ?? 'medium', 'medium' ),
			'titleCustomSize'       => self::normalize_float( $attributes['titleCustomSize'] ?? 0, 0, 0, 96 ),
			'titleFontStyle'        => self::allowlisted_value( $attributes['titleFontStyle'] ?? '', array( '', 'normal', 'italic' ), '' ),
			'titleFontWeight'       => self::allowlisted_value( $attributes['titleFontWeight'] ?? '', array( '', '100', '200', '300', '400', '500', '600', '700', '800', '900' ), '' ),
			'titleLineHeight'       => self::normalize_optional_line_height( $attributes['titleLineHeight'] ?? '' ),
			'titleTransform'        => self::allowlisted_value( $attributes['titleTransform'] ?? 'uppercase', array( 'uppercase', 'none', 'lowercase', 'capitalize' ), 'uppercase' ),
			'priceSize'             => self::font_size_slug( $attributes['priceSize'] ?? 'small', 'small' ),
			'priceCustomSize'       => self::normalize_float( $attributes['priceCustomSize'] ?? 0, 0, 0, 64 ),
			'priceFontStyle'        => self::allowlisted_value( $attributes['priceFontStyle'] ?? '', array( '', 'normal', 'italic' ), '' ),
			'priceFontWeight'       => self::allowlisted_value( $attributes['priceFontWeight'] ?? '', array( '', '100', '200', '300', '400', '500', '600', '700', '800', '900' ), '' ),
			'priceLineHeight'       => self::normalize_optional_line_height( $attributes['priceLineHeight'] ?? '' ),
			'priceColor'            => self::normalize_css_color( $attributes['priceColor'] ?? '' ),
		);
	}

	/**
	 * Build presentation variables for the block wrapper.
	 *
	 * @param array<string,mixed> $attributes Normalized attributes.
	 * @return string
	 */
	private static function get_presentation_style( $attributes ) {
		$image_shape_values = array(
			'square' => '0',
			'soft'   => '0.5rem',
			'round'  => '999rem',
		);
		$image_margin_inline = 'auto';

		if ( 'left' === $attributes['textAlign'] ) {
			$image_margin_inline = '0 auto';
		} elseif ( 'right' === $attributes['textAlign'] ) {
			$image_margin_inline = 'auto 0';
		}

		$block_gap = self::block_gap_value( $attributes['style']['spacing']['blockGap'] ?? '' );
		$card_width = '' !== $attributes['imageWidthValue'] ? $attributes['imageWidthValue'] : '18rem';

		$styles = array(
			'--ran-ecwid-shop-teaser--image-aspect-ratio: ' . $attributes['imageAspectRatio'],
			'--ran-ecwid-shop-teaser--image-object-fit: ' . $attributes['imageFit'],
			'--ran-ecwid-shop-teaser--image-border-radius: ' . $image_shape_values[ $attributes['imageShape'] ],
			'--ran-ecwid-shop-teaser--card-inline-size: ' . $card_width,
			'--ran-ecwid-shop-teaser--image-margin-inline: ' . $image_margin_inline,
			'--ran-ecwid-shop-teaser--text-align: ' . $attributes['textAlign'],
			'--ran-ecwid-shop-teaser--justify-content: ' . self::justify_content_value( $attributes['textAlign'] ),
			'--ran-ecwid-shop-teaser--title-font-size: ' . self::font_size_value( $attributes['titleCustomSize'], self::font_size_preset_value( $attributes['titleSize'], 'medium', self::title_font_size_fallback( $attributes['titleSize'] ) ) ),
			'--ran-ecwid-shop-teaser--title-font-style: ' . ( '' !== $attributes['titleFontStyle'] ? $attributes['titleFontStyle'] : 'normal' ),
			'--ran-ecwid-shop-teaser--title-font-weight: ' . ( '' !== $attributes['titleFontWeight'] ? $attributes['titleFontWeight'] : '800' ),
			'--ran-ecwid-shop-teaser--title-line-height: ' . ( '' !== $attributes['titleLineHeight'] ? $attributes['titleLineHeight'] : '1.18' ),
			'--ran-ecwid-shop-teaser--title-text-transform: ' . $attributes['titleTransform'],
			'--ran-ecwid-shop-teaser--price-font-size: ' . self::font_size_value( $attributes['priceCustomSize'], self::font_size_preset_value( $attributes['priceSize'], 'small', self::price_font_size_fallback( $attributes['priceSize'] ) ) ),
			'--ran-ecwid-shop-teaser--price-font-style: ' . ( '' !== $attributes['priceFontStyle'] ? $attributes['priceFontStyle'] : 'normal' ),
			'--ran-ecwid-shop-teaser--price-font-weight: ' . ( '' !== $attributes['priceFontWeight'] ? $attributes['priceFontWeight'] : '400' ),
			'--ran-ecwid-shop-teaser--price-line-height: ' . ( '' !== $attributes['priceLineHeight'] ? $attributes['priceLineHeight'] : '1.4' ),
		);

		if ( '' !== $block_gap ) {
			$styles[] = '--ran-ecwid-shop-teaser--gap: ' . $block_gap;
		} elseif ( self::is_non_default_float( $attributes['gridGap'], 1.5 ) ) {
			$styles[] = '--ran-ecwid-shop-teaser--gap: ' . $attributes['gridGap'] . 'rem';
		}

		$title_color = '' !== $attributes['titleColor']
			? $attributes['titleColor']
			: ( '' !== $attributes['descriptionColor'] ? $attributes['descriptionColor'] : $attributes['textColor'] );
		$price_color = '' !== $attributes['priceColor'] ? $attributes['priceColor'] : $attributes['textColor'];

		if ( '' !== $title_color ) {
			$styles[] = '--ran-ecwid-shop-teaser--title-color: ' . $title_color;
		}

		if ( '' !== $price_color ) {
			$styles[] = '--ran-ecwid-shop-teaser--price-color: ' . $price_color;
		}

		$styles = array_merge(
			$styles,
			self::box_spacing_styles( $attributes['style']['spacing']['padding'] ?? array(), 'padding' ),
			self::box_spacing_styles( $attributes['style']['spacing']['margin'] ?? array(), 'margin' )
		);

		return implode( '; ', $styles );
	}

	/**
	 * Resolve the core Dimensions block-gap attribute for the grid gap variable.
	 *
	 * @param mixed $value Raw spacing.blockGap value.
	 * @return string
	 */
	private static function block_gap_value( $value ) {
		if ( is_array( $value ) ) {
			$row_gap    = self::spacing_value( $value['top'] ?? '' );
			$column_gap = self::spacing_value( $value['left'] ?? '' );

			return trim( implode( ' ', array_filter( array( $row_gap, $column_gap ) ) ) );
		}

		return self::spacing_value( $value );
	}

	/**
	 * Resolve product-list row alignment from the text alignment control.
	 *
	 * @param string $text_align Text alignment.
	 * @return string
	 */
	private static function justify_content_value( $text_align ) {
		if ( 'left' === $text_align ) {
			return 'flex-start';
		}

		if ( 'right' === $text_align ) {
			return 'flex-end';
		}

		return 'center';
	}

	/**
	 * Resolve a core spacing value into CSS we can safely place in a custom property.
	 *
	 * @param mixed $value Raw spacing value.
	 * @return string
	 */
	private static function spacing_value( $value ) {
		if ( ! is_string( $value ) ) {
			return '';
		}

		$value = trim( $value );

		if ( '' === $value ) {
			return '';
		}

		if ( preg_match( '/^var:preset\|spacing\|([a-z0-9-]+)$/i', $value, $matches ) ) {
			return 'var(--wp--preset--spacing--' . sanitize_title( $matches[1] ) . ')';
		}

		if (
			preg_match( '/^var\(--wp--preset--spacing--[a-z0-9-]+\)$/i', $value ) ||
			preg_match( '/^0(?:\.0+)?$/', $value ) ||
			preg_match( '/^\d*\.?\d+(px|rem|em|%|vw|vh)$/i', $value ) ||
			preg_match( '/^(?:clamp|calc)\([a-z0-9.,+\-*\/% ()]+\)$/i', $value )
		) {
			return $value;
		}

		return '';
	}

	/**
	 * Resolve box spacing side values into CSS declarations.
	 *
	 * @param mixed  $value Raw spacing box value.
	 * @param string $property CSS property prefix.
	 * @return array<int,string>
	 */
	private static function box_spacing_styles( $value, $property ) {
		if ( ! is_array( $value ) ) {
			return array();
		}

		$styles = array();
		$sides  = array( 'top', 'right', 'bottom', 'left' );

		foreach ( $sides as $side ) {
			$spacing_value = self::spacing_value( $value[ $side ] ?? '' );

			if ( '' !== $spacing_value ) {
				$styles[] = $property . '-' . $side . ': ' . $spacing_value;
			}
		}

		return $styles;
	}

	/**
	 * Resolve custom pixel size or fallback preset.
	 *
	 * @param float  $custom_size Custom size in pixels.
	 * @param string $fallback Fallback CSS value.
	 * @return string
	 */
	private static function font_size_value( $custom_size, $fallback ) {
		if ( $custom_size <= 0 ) {
			return $fallback;
		}

		return $custom_size . 'px';
	}

	/**
	 * Resolve a font-size preset slug to the CSS variable emitted by theme.json.
	 *
	 * @param string $slug Font size slug.
	 * @param string $fallback_slug Fallback slug.
	 * @param string $fallback_size Fallback CSS size.
	 * @return string
	 */
	private static function font_size_preset_value( $slug, $fallback_slug, $fallback_size ) {
		$slug = self::font_size_slug( $slug, $fallback_slug );

		return sprintf(
			'var(--wp--preset--font-size--%1$s, %2$s)',
			$slug,
			$fallback_size
		);
	}

	/**
	 * Get generic fallback sizes for title presets.
	 *
	 * @param string $slug Font size slug.
	 * @return string
	 */
	private static function title_font_size_fallback( $slug ) {
		$sizes = array(
			'small'   => '0.875rem',
			'medium'  => '1.25rem',
			'large'   => '1.5rem',
			'x-large' => '2rem',
		);

		return $sizes[ $slug ] ?? '1.25rem';
	}

	/**
	 * Get generic fallback sizes for price presets.
	 *
	 * @param string $slug Font size slug.
	 * @return string
	 */
	private static function price_font_size_fallback( $slug ) {
		$sizes = array(
			'small'   => '0.875rem',
			'medium'  => '1rem',
			'large'   => '1.125rem',
			'x-large' => '1.25rem',
		);

		return $sizes[ $slug ] ?? '0.875rem';
	}

	/**
	 * Normalize a theme font-size preset slug.
	 *
	 * @param mixed  $value Raw value.
	 * @param string $fallback Fallback slug.
	 * @return string
	 */
	private static function font_size_slug( $value, $fallback ) {
		$value = is_string( $value ) ? sanitize_title( $value ) : '';

		return '' !== $value ? $value : $fallback;
	}

	/**
	 * Check whether an optional legacy float differs from its default.
	 *
	 * @param mixed $value Raw value.
	 * @param float $default Default value.
	 * @return bool
	 */
	private static function is_non_default_float( $value, $default ) {
		return is_numeric( $value ) && abs( (float) $value - $default ) > 0.0001;
	}

	/**
	 * Normalize a float.
	 *
	 * @param mixed $value Raw value.
	 * @param float $fallback Fallback value.
	 * @param float $min Minimum value.
	 * @param float $max Maximum value.
	 * @return float
	 */
	private static function normalize_float( $value, $fallback, $min, $max ) {
		if ( ! is_numeric( $value ) ) {
			return $fallback;
		}

		return min( $max, max( $min, (float) $value ) );
	}

	/**
	 * Normalize an optional float.
	 *
	 * @param mixed $value Raw value.
	 * @param float $min Minimum value.
	 * @param float $max Maximum value.
	 * @return string
	 */
	private static function normalize_optional_float( $value, $min, $max ) {
		if ( '' === $value || ! is_numeric( $value ) ) {
			return '';
		}

		return (string) min( $max, max( $min, (float) $value ) );
	}

	/**
	 * Normalize editor line-height values to numeric CSS values.
	 *
	 * @param mixed $value Raw value.
	 * @return string
	 */
	private static function normalize_optional_line_height( $value ) {
		if ( is_array( $value ) ) {
			$value = $value['value'] ?? $value['slug'] ?? '';
		}

		$value = is_string( $value ) || is_numeric( $value ) ? self::line_height_token( (string) $value ) : '';

		if ( '' === $value ) {
			return '';
		}

		$token_values = array(
			'low'    => '1.1',
			'small'  => '1.1',
			'normal' => '1.4',
			'medium' => '1.4',
			'high'   => '1.7',
			'large'  => '1.7',
		);

		if ( isset( $token_values[ $value ] ) ) {
			return $token_values[ $value ];
		}

		return self::normalize_optional_float( $value, 0.8, 3 );
	}

	/**
	 * Normalize line-height preset token syntax to a slug.
	 *
	 * @param string $value Raw value.
	 * @return string
	 */
	private static function line_height_token( $value ) {
		$value = strtolower( trim( $value ) );

		if ( preg_match( '/^var:preset\|line-height\|([a-z0-9-]+)$/i', $value, $matches ) ) {
			return sanitize_title( $matches[1] );
		}

		if ( preg_match( '/^var\(--wp--preset--line-height--([a-z0-9-]+)\)$/i', $value, $matches ) ) {
			return sanitize_title( $matches[1] );
		}

		return $value;
	}

	/**
	 * Normalize a hex color.
	 *
	 * @param mixed $value Raw color value.
	 * @return string
	 */
	private static function normalize_css_color( $value ) {
		$value = is_string( $value ) ? $value : '';
		$color = sanitize_hex_color( $value );

		if ( is_string( $color ) ) {
			return $color;
		}

		if ( preg_match( '/^var\(--wp--preset--color--[a-z0-9-]+\)$/i', $value ) ) {
			return $value;
		}

		if ( preg_match( '/^var:preset\|color\|([a-z0-9-]+)$/i', $value, $matches ) ) {
			return 'var(--wp--preset--color--' . sanitize_title( $matches[1] ) . ')';
		}

		return '';
	}

	/**
	 * Normalize a string to an allowed value.
	 *
	 * @param mixed         $value Raw value.
	 * @param array<int,string> $allowed Allowed values.
	 * @param string        $fallback Fallback value.
	 * @return string
	 */
	private static function allowlisted_value( $value, $allowed, $fallback ) {
		$value = is_string( $value ) ? $value : '';

		return in_array( $value, $allowed, true ) ? $value : $fallback;
	}

	/**
	 * Whether fallback/debug details should be visible on the rendered page.
	 *
	 * @param string $message Debug message.
	 * @return bool
	 */
	private static function should_render_debug_notice( $message ) {
		return '' !== $message && current_user_can( 'edit_posts' ) && defined( 'WP_DEBUG' ) && WP_DEBUG;
	}

	/**
	 * Render empty/editor state.
	 *
	 * @param string $message Message.
	 * @return string
	 */
	private static function render_empty_state( $message ) {
		if ( ! current_user_can( 'edit_posts' ) ) {
			return '';
		}

		if ( '' === $message ) {
			$message = __( 'No Ecwid products are available for this grid.', 'ran-ecwid-shop-teaser' );
		}

		return sprintf(
			'<div class="ran-ecwid-shop-teaser ran-ecwid-shop-teaser--empty"><p class="ran-ecwid-shop-teaser__notice">%s</p></div>',
			esc_html( $message )
		);
	}
}
