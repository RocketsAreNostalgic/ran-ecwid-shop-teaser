<?php
/**
 * Product-grid integration tests.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

class RAN_Ecwid_Shop_Teaser_Product_Grid_Test extends WP_UnitTestCase {
	/**
	 * Provide a stable fallback card without requiring external Ecwid access.
	 *
	 * @param array<int,array<string,mixed>> $products Fallback cards.
	 * @return array<int,array<string,mixed>>
	 */
	public function fallback_products( $products ) {
		return array(
			array(
				'id'        => 1,
				'name'      => 'Test product',
				'price'     => '$10.00',
				'image_url' => 'https://example.com/product.jpg',
				'image_alt' => 'A test product image',
				'url'       => 'https://example.com/product/',
				'enabled'   => true,
				'in_stock'  => false,
			)
		);
	}

	/**
	 * Ensure the compiled metadata registers the expected public block name.
	 *
	 * @return void
	 */
	public function test_registers_the_public_block_name() {
		$this->assertTrue( WP_Block_Type_Registry::get_instance()->is_registered( 'ran/ecwid-shop-teaser' ) );
	}

	/**
	 * Preserve legacy descriptionColor values and emit one accessible product link.
	 *
	 * @return void
	 */
	public function test_renders_legacy_title_colour_and_single_product_link() {
		add_filter( 'ran_ecwid_shop_teaser_static_fallback_products', array( $this, 'fallback_products' ) );

		$markup = do_blocks(
			'<!-- wp:ran/ecwid-shop-teaser {"categoryId":1,"showUnavailable":true,"descriptionColor":"#123456"} /-->'
		);

		remove_filter( 'ran_ecwid_shop_teaser_static_fallback_products', array( $this, 'fallback_products' ) );

		$this->assertSame( 1, substr_count( $markup, '<a ' ) );
		$this->assertStringContainsString( '--ran-ecwid-shop-teaser--title-color: #123456', $markup );
		$this->assertStringContainsString( 'ran-ecwid-shop-teaser-card--unavailable', $markup );
		$this->assertStringContainsString( 'Unavailable', $markup );
	}
}
