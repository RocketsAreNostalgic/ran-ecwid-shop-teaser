<?php
/**
 * Normalize generated metadata and restore the Release Please annotation.
 *
 * WP-CLI derives the bug-report slug from the checkout directory and writes
 * environment-specific creation and generator metadata. Remove that source of
 * drift so regenerating the POT is reproducible across local worktrees and CI.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

$path     = dirname( __DIR__ ) . '/languages/ran-ecwid-shop-teaser.pot';
$contents = file_get_contents( $path );

if ( false === $contents ) {
	fwrite( STDERR, "Could not read the translation template.\n" );
	exit( 1 );
}

$contents = preg_replace(
	'/^"Report-Msgid-Bugs-To:.*\\\\n"$/m',
	'"Report-Msgid-Bugs-To: https://wordpress.org/support/plugin/ran-ecwid-shop-teaser\\n"',
	$contents,
	1
);
$contents = preg_replace( '/^"(?:POT-Creation-Date|X-Generator):.*\\\\n"\R?/m', '', $contents );

if (
	null === $contents ||
	! str_contains( $contents, '"Report-Msgid-Bugs-To: https://wordpress.org/support/plugin/ran-ecwid-shop-teaser\\n"' )
) {
	fwrite( STDERR, "Could not normalize the translation template metadata.\n" );
	exit( 1 );
}

$start = '# x-release-please-start-version';
$end   = '# x-release-please-end';

$contents = str_replace( array( $start . "\n", $end . "\n" ), '', $contents );

$header_end = strpos( $contents, "\n\n", strpos( $contents, 'msgid ""' ) );

if ( false === $header_end ) {
	fwrite( STDERR, "Could not find the translation template header.\n" );
	exit( 1 );
}

$contents = substr_replace(
	$contents,
	"\n" . $end,
	$header_end,
	0
);

$header_start = strrpos( substr( $contents, 0, strpos( $contents, 'msgid ""' ) ), "\n" );

if ( false === $header_start ) {
	fwrite( STDERR, "Could not find the translation template header start.\n" );
	exit( 1 );
}

$contents = substr_replace(
	$contents,
	"\n" . $start,
	$header_start,
	0
);

if ( false === file_put_contents( $path, $contents ) ) {
	fwrite( STDERR, "Could not write the translation template.\n" );
	exit( 1 );
}
