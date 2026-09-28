# PHP quality coverage

Audit baseline: `274b1091deae7148c13a961414a8b74eaa288253` (issue #34).

## Source selection

- Plugin entrypoint and `includes/`: PHP syntax and shared RAN PHPCS rules.
- Authored PHP block templates in `blocks/`: PHP syntax and the same PHPCS/PHPCBF rules.
- `index.asset.php` build metadata: PHP syntax; generated metadata is verified by the build gate.
- Runtime copies in `build/blocks/`: PHP syntax and required generated-file parity with source.
- PHP development tools and tests: PHP syntax; broader PHPCS adoption needs its own measured slice.
- `vendor/`, `node_modules/`, `.git/`: excluded from first-party syntax/standards selection.

The block render template delegates to `EcwidProductGrid::render()`, which
escapes dynamic values while constructing complete HTML. Its single output
line has a justified escaping suppression; escaping checks remain enabled
elsewhere in the template and throughout the renderer.

## Commands and test environments

`composer check` runs syntax, standards, `test:quality` and `analyze`. The latter needs
Python 3 (already used by the package's observer contract tests), PHP and the
locked Composer tools. It runs the real syntax helper on disposable copies,
including malformed PHP, shell-sensitive filenames, dependency exclusions and
an unreadable source directory. The permission test is skipped under root,
which bypasses directory permissions. It also proves the block template is
selected by PHPCS, escaping remains enforced outside the justified output
line, and two PHPCBF passes leave the selected clean source byte-identical.
The repository source is never mutated by these tests.

Both existing PHPUnit files extend `WP_UnitTestCase`; their bootstrap loads
the WordPress test library, plugin and database environment. They remain under
`composer test:integration` in the required WordPress 6.5/PHP 8.0 and current
WordPress/PHP 8.3 matrix. They are not ordinary database-free tests.

PHPCS and PHPCBF use the same configuration. There is no PHP-CS-Fixer
dependency, configuration or caller to retire. Frontend Prettier, ESLint and
Stylelint have distinct responsibilities. Generated block/POT checks, archive
verification, fresh-ZIP activation and Plugin Check remain required CI gates.

## Static analysis

Blocking PHPStan level 5 targets PHP 8.0 with a 512 MB ceiling. Direct roots cover
all 15 PHP paths in the plugin entrypoint, includes, source/generated block
PHP and maintained release/syntax/POT tools. WordPress 6.5.7 stubs are symbols,
not installed execution; bootstrap values model runtime paths and time constants.
The render template documents the attributes injected by WordPress's render-file
context; source and generated copies retain identical executable behavior.

`treatPhpDocTypesAsCertain: false` preserves defensive validation of values from
WordPress, external APIs and native functions rather than treating annotations as
runtime guarantees. In particular, the release-path guard is retained unchanged.
No error baseline, ignored diagnostic, production type cast or runtime API change
is introduced. The optional Ecwid bridge retains its actual guarded discovery;
this floor is not certification against every version of the third-party plugin.

Tests remain under syntax and required installed WordPress integration; they are
not counted as production analysis. Analyzer support is development-only and
outside the archive allowlist. Existing generated/ZIP/install/Plugin Check proof
remains required. Fifteen individual wrong-return negative controls failed in the
configured analysis and were restored; the deterministic archive check passes.

## Remaining issue #34 scope

Exact-head native CI/review must qualify this analysis candidate. Development-tool/
test PHPCS coverage and the existing Ecwid camelCase property exception remain
separate audit follow-ups; this analysis change does not broaden those waivers.
