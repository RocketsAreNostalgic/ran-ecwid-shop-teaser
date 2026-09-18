# WordPress.org deployment

WordPress.org publication is currently disabled for this repository.

The normal GitHub release publisher does **not** deploy to WordPress.org and
does not expose a manual deployment dispatch. Its responsibility ends after it
has published and read back the exact GitHub tag, release, ZIP, SHA-256 file,
and manifest.

`deployment.json` remains disabled and records no active WordPress.org slug.
Do not add deployment credentials or treat the existing deployment helper as an
active publication path.

If this plugin is later approved for WordPress.org, introduce deployment as a
separate reviewed workflow. That workflow should:

- run behind the protected `wordpress-org` GitHub Environment;
- require explicit deployment authorization;
- consume the already-published, exact GitHub release assets;
- verify their tag, commit, manifest, and checksum before SVN mutation; and
- keep listing-artwork synchronization an explicit opt-in operation.

Do not re-add WordPress.org deployment, deployment inputs, or SVN credentials to
the normal Release Please publisher.
