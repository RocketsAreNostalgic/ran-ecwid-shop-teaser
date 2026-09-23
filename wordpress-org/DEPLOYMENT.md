# WordPress.org deployment

WordPress.org publication is currently disabled in `deployment.json`. It
records no active WordPress.org slug, so GitHub release qualification and
immutable publication require no SVN credentials.

The downstream `deploy-wordpress-org.yml` observer runs after a successful
Profile B workflow. It selects only an exact stable immutable GitHub release,
binds its ZIP/checksum digests to the triggering Profile B run's exact main
Quality artifact, and reads the committed deployment contract. With
`enabled: false`, it completes without
entering the protected `wordpress-org` environment or touching SVN.

If approved later, a reviewed change must set a real directory slug and
`enabled: true` in the committed contract. The protected environment then
downloads only the published ZIP and checksum and checks their release
identity, tag target, GitHub asset digests, and ZIP checksum before SVN work.
Listing artwork synchronization requires `syncListingAssets: true` in the
committed contract. A rerun accepts an existing SVN tag only when its files
match the exact ZIP; different bytes fail closed. A new SVN deployment also
rejects an older version than either an existing stable SVN tag or the checked-out
trunk, including a partial deployment whose tag copy failed. An untagged trunk
at the same version also fails closed before changing bytes.
Deployment never rebuilds or replaces GitHub release bytes.
