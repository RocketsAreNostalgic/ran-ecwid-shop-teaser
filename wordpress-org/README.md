# WordPress.org directory assets

This directory documents the separate WordPress.org SVN `assets/` directory.
The approved raster candidates are staged separately in `../wordpress-org-assets/`
and are intentionally not included in the plugin ZIP.

Run `pnpm wordpress-org:prepare` to generate ignored local SVN `trunk/` and
`tags/1.0.0/` trees from the validated release archive. The command never
contacts WordPress.org or commits anything remotely.

Before submission, confirm the approved, project-owned raster assets use these
names:

-   `icon-128x128.png` and `icon-256x256.png`
-   `banner-772x250.png` and `banner-1544x500.png`
-   `screenshot-1.png`: block inserter and inspector controls
-   `screenshot-2.png`: product grid in a theme without custom presets
-   `screenshot-3.png`: unavailable-product state and keyboard focus

All screenshots must use product imagery the publisher is permitted to
redistribute. Replace this file with the approved assets when copying this
directory to the WordPress.org SVN `assets/` directory.
