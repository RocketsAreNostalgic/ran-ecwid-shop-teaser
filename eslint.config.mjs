import ranWordPress from '@rocketsarenostalgic/quality-config/eslint/wordpress';

export default [
	...ranWordPress,
	{
		files: ['blocks/**/*.js'],
		rules: {
			'@wordpress/no-unsafe-wp-apis': 'off',
		},
	},
];
