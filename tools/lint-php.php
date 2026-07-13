<?php
/**
 * Syntax-check every PHP file shipped with the plugin.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

$root      = dirname( __DIR__ );
$skip_dirs = array( '.git', 'node_modules', 'vendor' );
$errors    = array();
$iterator  = new RecursiveIteratorIterator(
	new RecursiveDirectoryIterator( $root, FilesystemIterator::SKIP_DOTS )
);

foreach ( $iterator as $file ) {
	$relative_path = ltrim( str_replace( $root, '', $file->getPathname() ), DIRECTORY_SEPARATOR );
	$path_parts    = explode( DIRECTORY_SEPARATOR, $relative_path );

	if ( array_intersect( $skip_dirs, $path_parts ) || 'php' !== $file->getExtension() ) {
		continue;
	}

	$process = proc_open(
		array( PHP_BINARY, '-l', $file->getPathname() ),
		array(
			1 => array( 'pipe', 'w' ),
			2 => array( 'pipe', 'w' ),
		),
		$pipes
	);

	if ( ! is_resource( $process ) ) {
		$errors[] = 'Could not start PHP lint for ' . $relative_path;
		continue;
	}

	$output      = stream_get_contents( $pipes[1] ) . stream_get_contents( $pipes[2] );
	$exit_status = proc_close( $process );

	if ( 0 !== $exit_status ) {
		$errors[] = trim( $output );
	}
}

if ( $errors ) {
	fwrite( STDERR, implode( PHP_EOL, $errors ) . PHP_EOL );
	exit( 1 );
}

fwrite( STDOUT, "PHP syntax check passed.\n" );
