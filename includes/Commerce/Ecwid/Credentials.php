<?php
/**
 * Ecwid credential access.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

namespace RAN\EcwidShopTeaser\Commerce\Ecwid;

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Resolves Ecwid credentials through the guarded Ecwid plugin adapter.
 */
final class Credentials {
	/**
	 * Ecwid plugin adapter.
	 *
	 * @var EcwidPluginAdapter
	 */
	private $adapter;

	/**
	 * Constructor.
	 *
	 * @param EcwidPluginAdapter|null $adapter Ecwid adapter.
	 */
	public function __construct( $adapter = null ) {
		$this->adapter = $adapter instanceof EcwidPluginAdapter ? $adapter : new EcwidPluginAdapter();
	}

	/**
	 * Get store ID.
	 *
	 * @return int
	 */
	public function get_store_id() {
		$store_id = $this->adapter->get_store_id();

		/**
		 * Filters the Ecwid store ID used by the product grid.
		 *
		 * The installed Ecwid plugin is the default provider, but themes or
		 * companion plugins may supply credentials without adding block UI.
		 *
		 * @param int                $store_id Resolved Ecwid store ID.
		 * @param EcwidPluginAdapter $adapter Ecwid plugin adapter.
		 */
		return absint( apply_filters( 'ran_ecwid_shop_teaser_store_id', $store_id, $this->adapter ) );
	}

	/**
	 * Get token.
	 *
	 * @return string
	 */
	public function get_token() {
		$token = $this->adapter->get_token();

		/**
		 * Filters the Ecwid API token used by the product grid.
		 *
		 * Return an empty string to disable direct REST access. Never expose the
		 * token in rendered markup, logs, or public diagnostics.
		 *
		 * @param string             $token Resolved Ecwid API token.
		 * @param EcwidPluginAdapter $adapter Ecwid plugin adapter.
		 */
		$token = apply_filters( 'ran_ecwid_shop_teaser_token', $token, $this->adapter );

		return is_string( $token ) ? $token : '';
	}

	/**
	 * Whether credentials are sufficient for REST calls.
	 *
	 * @return bool
	 */
	public function is_available() {
		return 0 < $this->get_store_id() && '' !== $this->get_token();
	}
}
