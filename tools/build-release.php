<?php
/**
 * Build and validate the RAN Ecwid Shop Teaser runtime archive.
 *
 * Usage: php tools/build-release.php [--check] [--output=/absolute/archive.zip]
 *
 * @package RAN_Ecwid_Shop_Teaser
 */

// phpcs:disable WordPress.WP.AlternativeFunctions -- This standalone CLI tool runs without WordPress or WP_Filesystem.

const RAN_ECWID_RELEASE_SLUG  = 'ran-ecwid-shop-teaser';
const RAN_ECWID_RELEASE_MTIME = 315532800;

/**
 * Read the WordPress plugin header version.
 *
 * @param string $root Plugin root.
 * @return string
 * @throws RuntimeException When the plugin header cannot be read.
 */
function ran_ecwid_release_plugin_version( $root ) {
	$plugin_file = file_get_contents( $root . '/' . RAN_ECWID_RELEASE_SLUG . '.php' );

	if ( false === $plugin_file || ! preg_match( '/^ \* Version:\s*([^\r\n]+)$/m', $plugin_file, $matches ) ) {
		throw new RuntimeException( 'Unable to read the plugin header version.' );
	}

	return trim( $matches[1] );
}

/**
 * Return every explicitly shippable runtime file, in deterministic order.
 *
 * Source, tests, tooling, packaging metadata, and WordPress.org listing assets
 * remain excluded even when a new file is added to the repository.
 *
 * @param string $root Plugin root.
 * @return array<int,string>
 * @throws RuntimeException When a required runtime directory is unavailable.
 */
function ran_ecwid_release_files( $root ) {
	$paths = array(
		'LICENSE',
		'ran-ecwid-shop-teaser.php',
		'readme.txt',
		'languages/ran-ecwid-shop-teaser.pot',
	);

	foreach ( array( 'includes', 'build/blocks' ) as $directory ) {
		$directory_path = $root . '/' . $directory;

		if ( ! is_dir( $directory_path ) ) {
			// phpcs:ignore WordPress.Security.EscapeOutput.ExceptionNotEscaped -- This is a local CLI error message.
			throw new RuntimeException( 'Required runtime directory is missing: ' . $directory );
		}

		$iterator = new RecursiveIteratorIterator(
			new RecursiveDirectoryIterator( $directory_path, FilesystemIterator::SKIP_DOTS )
		);

		foreach ( $iterator as $file ) {
			if ( $file->isFile() ) {
				$paths[] = str_replace( DIRECTORY_SEPARATOR, '/', ltrim( str_replace( $root, '', $file->getPathname() ), DIRECTORY_SEPARATOR ) );
			}
		}
	}

	sort( $paths, SORT_STRING );

	foreach ( $paths as $path ) {
		if ( ! is_file( $root . '/' . $path ) ) {
			// phpcs:ignore WordPress.Security.EscapeOutput.ExceptionNotEscaped -- This is a local CLI error message.
			throw new RuntimeException( 'Required runtime file is missing: ' . $path );
		}
	}

	return $paths;
}

/**
 * Validate the version sources maintained by Release Please.
 *
 * @param string $root Plugin root.
 * @param string $version Expected version.
 * @return void
 * @throws RuntimeException When version sources differ.
 */
function ran_ecwid_release_validate_versions( $root, $version ) {
	$plugin_file = file_get_contents( $root . '/ran-ecwid-shop-teaser.php' );
	$package     = file_get_contents( $root . '/package.json' );
	$pot         = file_get_contents( $root . '/languages/ran-ecwid-shop-teaser.pot' );
	$readme      = file_get_contents( $root . '/readme.txt' );

	if (
		false === $plugin_file ||
		false === $package ||
		false === $pot ||
		false === $readme ||
		! str_contains( $plugin_file, "RAN_ECWID_SHOP_TEASER_VERSION', '" . $version . "'" ) ||
		! preg_match( '/"version"\s*:\s*"' . preg_quote( $version, '/' ) . '"/', $package ) ||
		! str_contains( $pot, 'Project-Id-Version: RAN Ecwid Shop Teaser ' . $version ) ||
		! preg_match( '/^Stable tag:\s*' . preg_quote( $version, '/' ) . '\s*$/mi', $readme )
	) {
		throw new RuntimeException( 'Plugin header, runtime constant, readme.txt, package.json, and POT project version must agree.' );
	}
}

/**
 * Read a requested archive output path.
 *
 * @param array<int,string> $arguments Command arguments.
 * @return string|null
 */
function ran_ecwid_release_output_path( $arguments ) {
	foreach ( $arguments as $index => $argument ) {
		if ( 0 === strpos( $argument, '--output=' ) ) {
			return substr( $argument, strlen( '--output=' ) );
		}

		if ( '--output' === $argument && isset( $arguments[ $index + 1 ] ) ) {
			return $arguments[ $index + 1 ];
		}
	}

	return null;
}

/**
 * Create one archive from the approved runtime files.
 *
 * @param string            $root Plugin root.
 * @param string            $archive_path Archive path.
 * @param array<int,string> $files Runtime relative paths.
 * @return void
 * @throws RuntimeException When the archive cannot be written.
 */
function ran_ecwid_release_create_archive( $root, $archive_path, $files ) {
	$archive = new ZipArchive();

	if ( true !== $archive->open( $archive_path, ZipArchive::CREATE | ZipArchive::OVERWRITE ) ) {
		throw new RuntimeException( 'Unable to create the release archive.' );
	}

	foreach ( $files as $file ) {
		$archive_path_name = RAN_ECWID_RELEASE_SLUG . '/' . $file;

		if (
			! $archive->addFile( $root . '/' . $file, $archive_path_name ) ||
			! $archive->setMtimeName( $archive_path_name, RAN_ECWID_RELEASE_MTIME ) ||
			! $archive->setCompressionName( $archive_path_name, ZipArchive::CM_DEFLATE, 9 )
		) {
			$archive->close();
			// phpcs:ignore WordPress.Security.EscapeOutput.ExceptionNotEscaped -- This is a local CLI error message.
			throw new RuntimeException( 'Unable to add a runtime file to the release archive: ' . $file );
		}
	}

	$archive->close();
}

/**
 * Validate the generated archive's exact runtime file list and release metadata.
 *
 * @param string            $archive_path Archive path.
 * @param array<int,string> $files Runtime relative paths.
 * @param string            $version Expected version.
 * @return void
 * @throws RuntimeException When the archive cannot be read or is invalid.
 */
function ran_ecwid_release_validate_archive( $archive_path, $files, $version ) {
	$archive = new ZipArchive();

	if ( true !== $archive->open( $archive_path ) ) {
		throw new RuntimeException( 'Unable to open the generated release archive.' );
	}

	$expected = array_map(
		static function ( $path ) {
			return RAN_ECWID_RELEASE_SLUG . '/' . $path;
		},
		$files
	);
	$actual   = array();

	// phpcs:ignore WordPress.NamingConventions.ValidVariableName.UsedPropertyNotSnakeCase -- ZipArchive API property.
	for ( $index = 0; $index < $archive->numFiles; $index++ ) {
		$name = $archive->getNameIndex( $index );

		if ( false === $name ) {
			$archive->close();
			throw new RuntimeException( 'Unable to read an archive entry.' );
		}

		$actual[] = $name;
	}

	sort( $actual, SORT_STRING );

	if ( $expected !== $actual ) {
		$archive->close();
		throw new RuntimeException( 'Release archive contents do not match the approved runtime file list.' );
	}

	$plugin_file = $archive->getFromName( RAN_ECWID_RELEASE_SLUG . '/ran-ecwid-shop-teaser.php' );
	$readme      = $archive->getFromName( RAN_ECWID_RELEASE_SLUG . '/readme.txt' );
	$archive->close();

	if (
		false === $plugin_file ||
		false === $readme ||
		! preg_match( '/^ \* Version:\s*' . preg_quote( $version, '/' ) . '\s*$/m', $plugin_file ) ||
		! preg_match( '/^Stable tag:\s*' . preg_quote( $version, '/' ) . '\s*$/mi', $readme )
	) {
		throw new RuntimeException( 'Release archive version metadata does not match the expected version.' );
	}
}

/**
 * Run the release archive builder.
 *
 * @param array<int,string> $arguments Command arguments, including the script path.
 * @return int Process exit status.
 */
function ran_ecwid_release_main( $arguments ) {
	$root        = dirname( __DIR__ );
	$arguments   = array_slice( $arguments, 1 );
	$check_only  = in_array( '--check', $arguments, true );
	$output_path = null;
	$check_copy  = null;

	try {
		if ( ! class_exists( 'ZipArchive' ) ) {
			throw new RuntimeException( 'The PHP ZipArchive extension is required to build release archives.' );
		}

		$version = ran_ecwid_release_plugin_version( $root );
		ran_ecwid_release_validate_versions( $root, $version );
		$files = ran_ecwid_release_files( $root );

		if ( ! in_array( 'build/blocks/ecwid-shop-teaser/block.json', $files, true ) ) {
			throw new RuntimeException( 'Compiled block assets are required before building a release archive.' );
		}

		$output_path = ran_ecwid_release_output_path( $arguments );
		if ( $check_only ) {
			$output_path = tempnam( sys_get_temp_dir(), RAN_ECWID_RELEASE_SLUG . '-' );
			$check_copy  = tempnam( sys_get_temp_dir(), RAN_ECWID_RELEASE_SLUG . '-' );
		} elseif ( null === $output_path || '' === $output_path ) {
			$output_path = $root . '/dist/' . RAN_ECWID_RELEASE_SLUG . '-' . $version . '.zip';
		}

		if ( false === $output_path || '' === $output_path ) {
			throw new RuntimeException( 'Unable to create a release archive path.' );
		}

		$parent_directory = dirname( $output_path );
		if ( ! is_dir( $parent_directory ) && ! mkdir( $parent_directory, 0755, true ) && ! is_dir( $parent_directory ) ) {
			throw new RuntimeException( 'Unable to create the release archive output directory.' );
		}

		if ( ! is_writable( $parent_directory ) ) {
			throw new RuntimeException( 'Release archive output directory must exist and be writable.' );
		}

		ran_ecwid_release_create_archive( $root, $output_path, $files );
		ran_ecwid_release_validate_archive( $output_path, $files, $version );

		if ( $check_only ) {
			if ( false === $check_copy ) {
				throw new RuntimeException( 'Unable to create a second temporary archive path.' );
			}

			ran_ecwid_release_create_archive( $root, $check_copy, $files );
			ran_ecwid_release_validate_archive( $check_copy, $files, $version );

			if ( hash_file( 'sha256', $output_path ) !== hash_file( 'sha256', $check_copy ) ) {
				throw new RuntimeException( 'Release archive is not reproducible across identical builds.' );
			}

			unlink( $output_path );
			unlink( $check_copy );
			fwrite( STDOUT, "Release archive validation passed.\n" );
			return 0;
		}

		fwrite( STDOUT, 'Created ' . $output_path . PHP_EOL );
		return 0;
	} catch ( Throwable $exception ) {
		if ( is_string( $output_path ) && is_file( $output_path ) && $check_only ) {
			unlink( $output_path );
		}

		if ( is_string( $check_copy ) && is_file( $check_copy ) ) {
			unlink( $check_copy );
		}

		fwrite( STDERR, $exception->getMessage() . PHP_EOL );
		return 1;
	}
}

// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- This is a CLI process exit status.
exit( ran_ecwid_release_main( $argv ) );
