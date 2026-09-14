import ranWordPress from '@rocketsarenostalgic/quality-config/eslint/wordpress';

export default [
	...ranWordPress,
	{
		files: ['blocks/**/*.js'],
		settings: {
			'import/core-modules': [
				'@wordpress/api-fetch',
				'@wordpress/block-editor',
				'@wordpress/blocks',
				'@wordpress/components',
				'@wordpress/element',
				'@wordpress/i18n',
			],
		},
		rules: {
			'@wordpress/no-unsafe-wp-apis': 'off',
		},
	},
];
