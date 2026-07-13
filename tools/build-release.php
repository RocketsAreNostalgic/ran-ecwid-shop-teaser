<?php
/**
 * Build and validate a WordPress.org-ready plugin archive from .distignore.
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

const RAN_ECWID_RELEASE_SLUG = 'ran-ecwid-shop-teaser';

/**
 * Read the repository archive exclusions.
 *
 * @param string $root Plugin root.
 * @return array<int,string>
 */
function ran_ecwid_release_rules( $root ) {
	$contents = file( $root . '/.distignore', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES );

	if ( false === $contents ) {
		throw new RuntimeException( 'Could not read .distignore.' );
	}

	return array_values(
		array_filter(
			array_map( 'trim', $contents ),
			static function ( $rule ) {
				return '' !== $rule && '#' !== substr( $rule, 0, 1 );
			}
		)
	);
}

/**
 * Decide whether a relative path must not ship in the archive.
 *
 * @param string            $relative_path Relative path.
 * @param array<int,string> $rules Archive exclusions.
 * @return bool
 */
function ran_ecwid_release_is_excluded( $relative_path, $rules ) {
	$relative_path = str_replace( DIRECTORY_SEPARATOR, '/', $relative_path );
	$first_segment = strtok( $relative_path, '/' );

	foreach ( $rules as $rule ) {
		$rule = trim( $rule, '/' );

		if ( $relative_path === $rule || $first_segment === $rule || 0 === strpos( $relative_path, $rule . '/' ) ) {
			return true;
		}
	}

	return false;
}

/**
 * Read the plugin version from the WordPress header.
 *
 * @param string $root Plugin root.
 * @return string
 */
function ran_ecwid_release_version( $root ) {
	$contents = file_get_contents( $root . '/' . RAN_ECWID_RELEASE_SLUG . '.php' );

	if ( false === $contents || ! preg_match( '/^ \* Version:\s*(.+)$/m', $contents, $matches ) ) {
		throw new RuntimeException( 'Could not read the plugin version from its header.' );
	}

	return trim( $matches[1] );
}

/**
 * Validate archive contents and source metadata.
 *
 * @param string $archive_path ZIP path.
 * @param string $version Expected version.
 * @return void
 */
function ran_ecwid_release_validate( $archive_path, $version ) {
	if ( ! class_exists( 'ZipArchive' ) ) {
		throw new RuntimeException( 'The PHP ZipArchive extension is required to validate release archives.' );
	}

	$archive = new ZipArchive();

	if ( true !== $archive->open( $archive_path ) ) {
		throw new RuntimeException( 'Could not open the release archive.' );
	}

	$root     = RAN_ECWID_RELEASE_SLUG . '/';
	$required = array(
		$root . RAN_ECWID_RELEASE_SLUG . '.php',
		$root . 'readme.txt',
		$root . 'LICENSE',
		$root . 'build/blocks/ecwid-shop-teaser/block.json',
		$root . 'build/blocks/ecwid-shop-teaser/index.js',
		$root . 'build/blocks/ecwid-shop-teaser/index.asset.php',
		$root . 'build/blocks/ecwid-shop-teaser/index.css',
		$root . 'build/blocks/ecwid-shop-teaser/style-index.css',
		$root . 'build/blocks/ecwid-shop-teaser/render.php',
	);

	foreach ( $required as $required_file ) {
		if ( false === $archive->locateName( $required_file ) ) {
			$archive->close();
			throw new RuntimeException( 'Archive is missing required file: ' . $required_file );
		}
	}

	$readme = $archive->getFromName( $root . 'readme.txt' );

	if ( false === $readme || ! preg_match( '/^Stable tag:\s*' . preg_quote( $version, '/' ) . '\s*$/mi', $readme ) ) {
		$archive->close();
		throw new RuntimeException( 'readme.txt Stable tag must match the plugin header version.' );
	}

	for ( $index = 0; $index < $archive->numFiles; $index++ ) {
		$name = $archive->getNameIndex( $index );

		if ( 0 !== strpos( $name, $root ) || false !== strpos( $name, '/node_modules/' ) || false !== strpos( $name, '/vendor/' ) || false !== strpos( $name, '/.git/' ) ) {
			$archive->close();
			throw new RuntimeException( 'Archive contains an invalid development path: ' . $name );
		}
	}

	$archive->close();
}

$root    = dirname( __DIR__ );
$version = ran_ecwid_release_version( $root );
$check   = in_array( '--check', $argv, true );

if ( ! class_exists( 'ZipArchive' ) ) {
	fwrite( STDERR, "The PHP ZipArchive extension is required to build release archives.\n" );
	exit( 1 );
}

$archive_path = $check
	? tempnam( sys_get_temp_dir(), RAN_ECWID_RELEASE_SLUG . '-' )
	: $root . '/dist/' . RAN_ECWID_RELEASE_SLUG . '-' . $version . '.zip';

if ( false === $archive_path ) {
	fwrite( STDERR, "Could not create a temporary release archive path.\n" );
	exit( 1 );
}

if ( ! $check && ! is_dir( dirname( $archive_path ) ) && ! mkdir( dirname( $archive_path ), 0755, true ) && ! is_dir( dirname( $archive_path ) ) ) {
	fwrite( STDERR, "Could not create the dist directory.\n" );
	exit( 1 );
}

$archive = new ZipArchive();

if ( true !== $archive->open( $archive_path, ZipArchive::CREATE | ZipArchive::OVERWRITE ) ) {
	fwrite( STDERR, "Could not create the release archive.\n" );
	exit( 1 );
}

$rules    = ran_ecwid_release_rules( $root );
$iterator = new RecursiveIteratorIterator(
	new RecursiveDirectoryIterator( $root, FilesystemIterator::SKIP_DOTS )
);

foreach ( $iterator as $file ) {
	if ( ! $file->isFile() ) {
		continue;
	}

	$relative_path = ltrim( str_replace( $root, '', $file->getPathname() ), DIRECTORY_SEPARATOR );

	if ( ran_ecwid_release_is_excluded( $relative_path, $rules ) ) {
		continue;
	}

	$archive->addFile( $file->getPathname(), RAN_ECWID_RELEASE_SLUG . '/' . str_replace( DIRECTORY_SEPARATOR, '/', $relative_path ) );
}

$archive->close();

try {
	ran_ecwid_release_validate( $archive_path, $version );
} catch ( Throwable $exception ) {
	@unlink( $archive_path );
	fwrite( STDERR, $exception->getMessage() . PHP_EOL );
	exit( 1 );
}

if ( $check ) {
	@unlink( $archive_path );
	fwrite( STDOUT, "Release archive validation passed.\n" );
	exit( 0 );
}

fwrite( STDOUT, 'Created ' . $archive_path . PHP_EOL );
