import apiFetch from '@wordpress/api-fetch';
import {
	ColorPalette,
	InspectorControls,
	LineHeightControl,
	useBlockProps,
	useSettings,
	__experimentalFontAppearanceControl as FontAppearanceControl,
	__experimentalUnitControl as BlockEditorUnitControl,
} from '@wordpress/block-editor';
import { registerBlockType } from '@wordpress/blocks';
import {
	Button,
	ColorIndicator,
	Dropdown,
	FontSizePicker,
	PanelBody,
	RangeControl,
	TextControl,
	ToggleControl,
	__experimentalBoxControl as BoxControl,
	__experimentalParseQuantityAndUnitFromRawValue as parseQuantityAndUnitFromRawValue,
	__experimentalToggleGroupControl as ToggleGroupControl,
	__experimentalToggleGroupControlOption as ToggleGroupControlOption,
	__experimentalToolsPanel as ToolsPanel,
	__experimentalToolsPanelItem as ToolsPanelItem,
	__experimentalUnitControl as ComponentsUnitControl,
} from '@wordpress/components';
import {
	createElement as el,
	Fragment,
	useEffect,
	useState,
} from '@wordpress/element';
import { __ } from '@wordpress/i18n';

import './editor.css';
import './style.css';

const UnitControl = BlockEditorUnitControl || ComponentsUnitControl;

const IMAGE_ASPECT_RATIO_OPTIONS = [
	{ label: __( 'Landscape 3:2', 'ran-ecwid-shop-teaser' ), value: '3 / 2' },
	{ label: __( 'Square 1:1', 'ran-ecwid-shop-teaser' ), value: '1 / 1' },
	{ label: __( 'Portrait 4:5', 'ran-ecwid-shop-teaser' ), value: '4 / 5' },
];
const IMAGE_FIT_OPTIONS = [
	{ label: __( 'Crop to fill', 'ran-ecwid-shop-teaser' ), value: 'cover' },
	{ label: __( 'Fit inside', 'ran-ecwid-shop-teaser' ), value: 'contain' },
];
const IMAGE_SHAPE_OPTIONS = [
	{ label: __( 'Square corners', 'ran-ecwid-shop-teaser' ), value: 'square' },
	{ label: __( 'Soft corners', 'ran-ecwid-shop-teaser' ), value: 'soft' },
	{ label: __( 'Round', 'ran-ecwid-shop-teaser' ), value: 'round' },
];
const TEXT_ALIGN_OPTIONS = [
	{ label: __( 'Align left', 'ran-ecwid-shop-teaser' ), value: 'left' },
	{ label: __( 'Align center', 'ran-ecwid-shop-teaser' ), value: 'center' },
	{ label: __( 'Align right', 'ran-ecwid-shop-teaser' ), value: 'right' },
];
const TITLE_SIZE_OPTIONS = [
	{
		label: __( 'Small', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'S',
		value: 'small',
	},
	{
		label: __( 'Medium', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'M',
		value: 'medium',
	},
	{
		label: __( 'Large', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'L',
		value: 'large',
	},
	{
		label: __( 'Extra Large', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'XL',
		value: 'x-large',
	},
];
const TITLE_TRANSFORM_OPTIONS = [
	{
		label: __( 'Uppercase', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'AA',
		value: 'uppercase',
	},
	{
		label: __( 'Normal case', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'Aa',
		value: 'none',
	},
	{
		label: __( 'Lowercase', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'aa',
		value: 'lowercase',
	},
	{
		label: __( 'Capitalize', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'Ab',
		value: 'capitalize',
	},
];
const PRICE_SIZE_OPTIONS = [
	{
		label: __( 'Small', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'S',
		value: 'small',
	},
	{
		label: __( 'Medium', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'M',
		value: 'medium',
	},
	{
		label: __( 'Large', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'L',
		value: 'large',
	},
	{
		label: __( 'Extra Large', 'ran-ecwid-shop-teaser' ),
		shortLabel: 'XL',
		value: 'x-large',
	},
];

const IMAGE_SHAPE_VALUES = {
	square: '0',
	soft: '0.5rem',
	round: '999rem',
};
const TITLE_SIZE_VALUES = {
	small: '0.875rem',
	medium: '1.25rem',
	large: '1.5rem',
	'x-large': '2rem',
};
const PRICE_SIZE_VALUES = {
	small: '0.875rem',
	medium: '1rem',
	large: '1.125rem',
	'x-large': '1.25rem',
};
const LINE_HEIGHT_TOKEN_VALUES = {
	low: '1.1',
	small: '1.1',
	normal: '1.4',
	medium: '1.4',
	high: '1.7',
	large: '1.7',
};
const FONT_STYLE_OPTIONS = [ { value: 'normal' }, { value: 'italic' } ];
const FONT_WEIGHT_OPTIONS = [
	{ value: '100' },
	{ value: '200' },
	{ value: '300' },
	{ value: '400' },
	{ value: '500' },
	{ value: '600' },
	{ value: '700' },
	{ value: '800' },
	{ value: '900' },
];
const TITLE_FONT_SIZE_PRESETS = TITLE_SIZE_OPTIONS.map( function ( option ) {
	return {
		name: option.label,
		slug: option.value,
		size: TITLE_SIZE_VALUES[ option.value ],
	};
} );
const PRICE_FONT_SIZE_PRESETS = PRICE_SIZE_OPTIONS.map( function ( option ) {
	return {
		name: option.label,
		slug: option.value,
		size: PRICE_SIZE_VALUES[ option.value ],
	};
} );
const DEFAULT_TITLE_FONT_SIZE_PRESET = 'medium';
const DEFAULT_PRICE_FONT_SIZE_PRESET = 'small';
const EMPTY_BOX_VALUES = {};
const DEFAULT_WRAPPER_SPACING_VALUE = '0px';
const DEFAULT_WRAPPER_SPACING_VALUES = {
	top: DEFAULT_WRAPPER_SPACING_VALUE,
	right: DEFAULT_WRAPPER_SPACING_VALUE,
	bottom: DEFAULT_WRAPPER_SPACING_VALUE,
	left: DEFAULT_WRAPPER_SPACING_VALUE,
};
const CARD_WIDTH_UNITS = [
	{ value: 'rem', label: 'rem', default: 18 },
	{ value: 'px', label: 'px', default: 240 },
	{ value: 'em', label: 'em', default: 16 },
	{ value: '%', label: '%', default: 100 },
	{ value: 'vw', label: 'vw', default: 25 },
];
const CARD_SPACING_UNITS = [
	{ value: 'rem', label: 'rem', default: 1.5 },
	{ value: 'px', label: 'px', default: 24 },
	{ value: 'em', label: 'em', default: 1.5 },
];
const WRAPPER_SPACING_UNITS = [
	{ value: 'px', label: 'px', default: 0 },
	{ value: 'rem', label: 'rem', default: 0 },
	{ value: 'em', label: 'em', default: 0 },
	{ value: '%', label: '%', default: 0 },
];
const PRODUCT_GRID_ICON = el(
	'svg',
	{
		'aria-hidden': 'true',
		focusable: 'false',
		viewBox: '0 0 24 24',
		xmlns: 'http://www.w3.org/2000/svg',
	},
	el( 'path', {
		d: 'M5.5 4h13l1.5 4.5H4L5.5 4Z',
		fill: 'currentColor',
	} ),
	el( 'path', {
		d: 'M5 10h4v4H5v-4Zm5 0h4v4h-4v-4Zm5 0h4v4h-4v-4ZM5 15h4v5H5v-5Zm5 0h4v5h-4v-5Zm5 0h4v5h-4v-5Z',
		fill: 'currentColor',
	} )
);
const TOOLS_PANEL_DROPDOWN_MENU_PROPS = {
	popoverProps: {
		placement: 'left-start',
		offset: 259,
	},
};
const DEFAULT_PRESENTATION_ATTRIBUTES = {
	gridGap: 1.5,
	imageAspectRatio: '3 / 2',
	imageFit: 'cover',
	imageShape: 'square',
	imageWidth: 18,
	imageWidthValue: '18rem',
	textAlign: 'center',
	textColor: '',
	titleColor: '',
	descriptionColor: '',
	titleSize: 'medium',
	titleCustomSize: 0,
	titleFontStyle: '',
	titleFontWeight: '',
	titleLineHeight: '',
	titleTransform: 'uppercase',
	priceSize: 'small',
	priceCustomSize: 0,
	priceFontStyle: '',
	priceFontWeight: '',
	priceLineHeight: '',
	priceColor: '',
};

function getPreviewItems( limit ) {
	const parsed = parseInt( limit, 10 );
	const count = Number.isNaN( parsed )
		? 3
		: Math.min( Math.max( parsed, 1 ), 24 );

	return Array.from( { length: count } );
}

function getOptionValue( value, options, fallback ) {
	return options.some( function ( option ) {
		return option.value === value;
	} )
		? value
		: fallback;
}

function getEditorFontSizePresets( fontSizes, fallbackPresets ) {
	const presets = [];
	const themePresetBySlug = {};

	if ( Array.isArray( fontSizes ) ) {
		fontSizes.forEach( function ( fontSize ) {
			if ( ! fontSize || ! fontSize.slug || ! fontSize.size ) {
				return;
			}

			const slug = String( fontSize.slug );
			themePresetBySlug[ slug ] = {
				name: fontSize.name || slug,
				slug,
				size: fontSize.size,
			};
		} );
	}

	fallbackPresets.forEach( function ( fontSize ) {
		const themePreset = themePresetBySlug[ fontSize.slug ];

		presets.push(
			themePreset
				? {
						name: fontSize.name,
						slug: fontSize.slug,
						size: themePreset.size,
				  }
				: fontSize
		);
	} );

	return presets;
}

function getFontSizeOptions( presets ) {
	return presets.map( function ( preset ) {
		return {
			label: preset.name || preset.slug,
			value: preset.slug,
		};
	} );
}

function getFontSizeValues( presets ) {
	return presets.reduce( function ( values, preset ) {
		values[ preset.slug ] = preset.size;
		return values;
	}, {} );
}

function getPresetCssVariable( type, slug ) {
	return 'var(--wp--preset--' + type + '--' + slug + ')';
}

function getFontSizePresetCssValue( slug, fallbackSize ) {
	return 'var(--wp--preset--font-size--' + slug + ', ' + fallbackSize + ')';
}

function getColorPresetSlug( value ) {
	if ( typeof value !== 'string' ) {
		return '';
	}

	const match = value
		.trim()
		.match( /^var\(--wp--preset--color--([a-z0-9-]+)\)$/i );

	return match ? match[ 1 ] : '';
}

function getColorControlValue( value, palette ) {
	const slug = getColorPresetSlug( value );

	if ( slug && Array.isArray( palette ) ) {
		const preset = palette.find( function ( color ) {
			return color && color.slug === slug;
		} );

		if ( preset && preset.color ) {
			return preset.color;
		}
	}

	return value || '';
}

function getSerializableColorValue( value, palette ) {
	if ( ! value ) {
		return '';
	}

	if ( Array.isArray( palette ) ) {
		const preset = palette.find( function ( color ) {
			return (
				color &&
				color.slug &&
				typeof color.color === 'string' &&
				color.color.toLowerCase() === String( value ).toLowerCase()
			);
		} );

		if ( preset ) {
			return getPresetCssVariable( 'color', preset.slug );
		}
	}

	return value;
}

function getClampedNumber( value, fallback, min, max ) {
	const parsed = parseFloat( value );

	if ( Number.isNaN( parsed ) ) {
		return fallback;
	}

	return Math.min( Math.max( parsed, min ), max );
}

function getLineHeightValue( value, fallback ) {
	if ( ! value ) {
		return fallback;
	}

	const normalized = getLineHeightToken( value );
	const tokenValue = LINE_HEIGHT_TOKEN_VALUES[ normalized ];

	if ( tokenValue ) {
		return tokenValue;
	}

	return getClampedNumber( normalized, fallback, 0.8, 3 );
}

function getLineHeightAttributeValue( value ) {
	if ( value && typeof value === 'object' ) {
		return getLineHeightAttributeValue( value.value || value.slug || '' );
	}

	if ( ! value ) {
		return '';
	}

	const normalized = getLineHeightToken( value );
	const tokenValue = LINE_HEIGHT_TOKEN_VALUES[ normalized ];

	if ( tokenValue ) {
		return tokenValue;
	}

	const parsed = parseFloat( normalized );

	if ( Number.isNaN( parsed ) ) {
		return '';
	}

	return String( Math.min( Math.max( parsed, 0.8 ), 3 ) );
}

function getLineHeightToken( value ) {
	const normalized = String( value ).trim().toLowerCase();
	const presetMatch =
		normalized.match( /^var:preset\|line-height\|([a-z0-9-]+)$/i ) ||
		normalized.match( /^var\(--wp--preset--line-height--([a-z0-9-]+)\)$/i );

	return presetMatch ? presetMatch[ 1 ] : normalized;
}

function getCustomPixelSize( value, max ) {
	const parsed = parseFloat( value );

	if ( Number.isNaN( parsed ) || parsed <= 0 ) {
		return '';
	}

	return Math.min( Math.max( parsed, 8 ), max ) + 'px';
}

function getSpacingPresetValue( value ) {
	if ( typeof value !== 'string' ) {
		return '';
	}

	const trimmed = value.trim();
	const presetMatch = trimmed.match( /^var:preset\|spacing\|([a-z0-9-]+)$/i );

	if ( presetMatch ) {
		return 'var(--wp--preset--spacing--' + presetMatch[ 1 ] + ')';
	}

	return trimmed;
}

function getBlockGapAttributeValue( attributes ) {
	const blockGap =
		attributes.style &&
		attributes.style.spacing &&
		attributes.style.spacing.blockGap;

	return blockGap;
}

function getBlockGapValue( attributes ) {
	const blockGap = getBlockGapAttributeValue( attributes );

	if ( blockGap && typeof blockGap === 'object' ) {
		const rowGap = getSpacingPresetValue( blockGap.top );
		const columnGap = getSpacingPresetValue( blockGap.left );

		return [ rowGap, columnGap ].filter( Boolean ).join( ' ' );
	}

	return getSpacingPresetValue( blockGap );
}

function getCardWidthValue( attributes ) {
	if (
		typeof attributes.imageWidthValue === 'string' &&
		attributes.imageWidthValue.trim()
	) {
		return attributes.imageWidthValue.trim();
	}

	return DEFAULT_PRESENTATION_ATTRIBUTES.imageWidthValue;
}

function getCardGapValue( attributes ) {
	const blockGap = getBlockGapValue( attributes );

	if ( blockGap ) {
		return blockGap;
	}

	return (
		getClampedNumber(
			attributes.gridGap,
			DEFAULT_PRESENTATION_ATTRIBUTES.gridGap,
			0,
			4
		) + 'rem'
	);
}

function getLengthControlValue( value, fallback, units ) {
	if ( typeof value !== 'string' ) {
		return fallback;
	}

	const trimmed = value.trim();
	const unitPattern = units
		.map( function ( unit ) {
			return unit.value.replace( /[.*+?^${}()|[\]\\]/g, '\\$&' );
		} )
		.join( '|' );
	const lengthPattern = new RegExp(
		'^-?\\d*\\.?\\d+(?:' + unitPattern + ')$',
		'i'
	);

	return lengthPattern.test( trimmed ) ? trimmed : fallback;
}

function getSpacingSideValue( attributes, key ) {
	return (
		attributes.style &&
		attributes.style.spacing &&
		attributes.style.spacing[ key ]
	);
}

function getStyleWithSpacingValue( attributes, key, value ) {
	const currentStyle =
		attributes.style && typeof attributes.style === 'object'
			? attributes.style
			: {};
	const currentSpacing =
		currentStyle.spacing && typeof currentStyle.spacing === 'object'
			? currentStyle.spacing
			: {};
	const nextSpacing = { ...currentSpacing };

	if (
		value === undefined ||
		value === null ||
		value === '' ||
		( typeof value === 'object' && ! Object.keys( value ).length )
	) {
		delete nextSpacing[ key ];
	} else {
		nextSpacing[ key ] = value;
	}

	return {
		...currentStyle,
		spacing: nextSpacing,
	};
}

function getStyleWithoutSpacingValues( attributes, keys ) {
	const currentStyle =
		attributes.style && typeof attributes.style === 'object'
			? attributes.style
			: {};
	const currentSpacing =
		currentStyle.spacing && typeof currentStyle.spacing === 'object'
			? currentStyle.spacing
			: {};
	const nextSpacing = { ...currentSpacing };

	keys.forEach( function ( key ) {
		delete nextSpacing[ key ];
	} );

	if ( Object.keys( nextSpacing ).length ) {
		return {
			...currentStyle,
			spacing: nextSpacing,
		};
	}

	const nextStyle = { ...currentStyle };
	delete nextStyle.spacing;

	return nextStyle;
}

function addBoxSpacingStyles( styles, attributes, key, property ) {
	const value = getSpacingSideValue( attributes, key );

	if ( ! value || typeof value !== 'object' ) {
		return styles;
	}

	const sideProperties = {
		top: property + 'Top',
		right: property + 'Right',
		bottom: property + 'Bottom',
		left: property + 'Left',
	};

	Object.keys( sideProperties ).forEach( function ( side ) {
		const spacingValue = getSpacingPresetValue( value[ side ] );

		if ( spacingValue ) {
			styles[ sideProperties[ side ] ] = spacingValue;
		}
	} );

	return styles;
}

function getParsedCssLength( value, fallbackUnit, fallbackValue ) {
	if ( parseQuantityAndUnitFromRawValue ) {
		const parsed = parseQuantityAndUnitFromRawValue( value );
		const quantity = parseFloat( parsed[ 0 ] );

		return {
			quantity: Number.isNaN( quantity ) ? fallbackValue : quantity,
			unit: parsed[ 1 ] || fallbackUnit,
		};
	}

	const match = String( value || '' ).match( /^(-?\d*\.?\d+)([a-z%]*)$/i );

	return {
		quantity: match ? parseFloat( match[ 1 ] ) : fallbackValue,
		unit: match && match[ 2 ] ? match[ 2 ] : fallbackUnit,
	};
}

function getCardWidthRangeConfig( unit ) {
	if ( '%' === unit || 'vw' === unit ) {
		return { max: 100, step: 1 };
	}

	if ( 'rem' === unit || 'em' === unit ) {
		return { max: 40, step: 0.1 };
	}

	return { max: 800, step: 1 };
}

function getCardSpacingRangeConfig( unit ) {
	if ( 'rem' === unit || 'em' === unit ) {
		return { max: 8, step: 0.1 };
	}

	return { max: 128, step: 1 };
}

function getImageMarginInline( textAlign ) {
	if ( textAlign === 'left' ) {
		return '0 auto';
	}

	if ( textAlign === 'right' ) {
		return 'auto 0';
	}

	return 'auto';
}

function getJustifyContent( textAlign ) {
	if ( textAlign === 'left' ) {
		return 'flex-start';
	}

	if ( textAlign === 'right' ) {
		return 'flex-end';
	}

	return 'center';
}

function getImageShapeShortLabel( value ) {
	if ( value === 'square' ) {
		return __( 'Square', 'ran-ecwid-shop-teaser' );
	}

	if ( value === 'soft' ) {
		return __( 'Soft', 'ran-ecwid-shop-teaser' );
	}

	return __( 'Round', 'ran-ecwid-shop-teaser' );
}

function getPresentationStyle( attributes, editorSettings = {} ) {
	const titleFontSizePresets = getEditorFontSizePresets(
		editorSettings.fontSizes,
		TITLE_FONT_SIZE_PRESETS
	);
	const priceFontSizePresets = getEditorFontSizePresets(
		editorSettings.fontSizes,
		PRICE_FONT_SIZE_PRESETS
	);
	const titleSizeOptions = getFontSizeOptions( titleFontSizePresets );
	const priceSizeOptions = getFontSizeOptions( priceFontSizePresets );
	const titleSizeValues = getFontSizeValues( titleFontSizePresets );
	const priceSizeValues = getFontSizeValues( priceFontSizePresets );
	const textAlign = getOptionValue(
		attributes.textAlign,
		TEXT_ALIGN_OPTIONS,
		'center'
	);
	const imageShape = getOptionValue(
		attributes.imageShape,
		IMAGE_SHAPE_OPTIONS,
		'square'
	);
	const titleSize = getOptionValue(
		attributes.titleSize,
		titleSizeOptions,
		DEFAULT_TITLE_FONT_SIZE_PRESET
	);
	const priceSize = getOptionValue(
		attributes.priceSize,
		priceSizeOptions,
		DEFAULT_PRICE_FONT_SIZE_PRESET
	);
	const imageMarginInline = getImageMarginInline( textAlign );
	const legacyTextColor = attributes.textColor || '';
	const titleColor =
		attributes.titleColor ||
		attributes.descriptionColor ||
		legacyTextColor;
	const priceColor = attributes.priceColor || legacyTextColor;
	const blockGap = getBlockGapValue( attributes );

	const styles = {
		'--ran-ecwid-shop-teaser--image-aspect-ratio': getOptionValue(
			attributes.imageAspectRatio,
			IMAGE_ASPECT_RATIO_OPTIONS,
			'3 / 2'
		),
		'--ran-ecwid-shop-teaser--image-object-fit': getOptionValue(
			attributes.imageFit,
			IMAGE_FIT_OPTIONS,
			'cover'
		),
		'--ran-ecwid-shop-teaser--image-border-radius':
			IMAGE_SHAPE_VALUES[ imageShape ],
		'--ran-ecwid-shop-teaser--card-inline-size':
			getCardWidthValue( attributes ),
		'--ran-ecwid-shop-teaser--image-margin-inline': imageMarginInline,
		'--ran-ecwid-shop-teaser--text-align': textAlign,
		'--ran-ecwid-shop-teaser--justify-content':
			getJustifyContent( textAlign ),
		'--ran-ecwid-shop-teaser--title-font-size':
			getCustomPixelSize( attributes.titleCustomSize, 96 ) ||
			titleSizeValues[ titleSize ] ||
			getFontSizePresetCssValue( titleSize, '1.25rem' ),
		'--ran-ecwid-shop-teaser--title-font-style': getOptionValue(
			attributes.titleFontStyle,
			FONT_STYLE_OPTIONS,
			'normal'
		),
		'--ran-ecwid-shop-teaser--title-font-weight': getOptionValue(
			attributes.titleFontWeight,
			FONT_WEIGHT_OPTIONS,
			'800'
		),
		'--ran-ecwid-shop-teaser--title-line-height': getLineHeightValue(
			attributes.titleLineHeight,
			1.18
		),
		'--ran-ecwid-shop-teaser--title-text-transform': getOptionValue(
			attributes.titleTransform,
			TITLE_TRANSFORM_OPTIONS,
			'uppercase'
		),
		'--ran-ecwid-shop-teaser--price-font-size':
			getCustomPixelSize( attributes.priceCustomSize, 64 ) ||
			priceSizeValues[ priceSize ] ||
			getFontSizePresetCssValue( priceSize, '0.875rem' ),
		'--ran-ecwid-shop-teaser--price-font-style': getOptionValue(
			attributes.priceFontStyle,
			FONT_STYLE_OPTIONS,
			'normal'
		),
		'--ran-ecwid-shop-teaser--price-font-weight': getOptionValue(
			attributes.priceFontWeight,
			FONT_WEIGHT_OPTIONS,
			'400'
		),
		'--ran-ecwid-shop-teaser--price-line-height': getLineHeightValue(
			attributes.priceLineHeight,
			1.4
		),
	};

	if ( blockGap ) {
		styles[ '--ran-ecwid-shop-teaser--gap' ] = blockGap;
	} else if (
		Number.isFinite( Number.parseFloat( attributes.gridGap ) ) &&
		Math.abs(
			Number.parseFloat( attributes.gridGap ) -
				DEFAULT_PRESENTATION_ATTRIBUTES.gridGap
		) > 0.0001
	) {
		styles[ '--ran-ecwid-shop-teaser--gap' ] =
			getClampedNumber(
				attributes.gridGap,
				DEFAULT_PRESENTATION_ATTRIBUTES.gridGap,
				0,
				4
			) + 'rem';
	}

	if ( titleColor ) {
		styles[ '--ran-ecwid-shop-teaser--title-color' ] = titleColor;
	}

	if ( priceColor ) {
		styles[ '--ran-ecwid-shop-teaser--price-color' ] = priceColor;
	}

	addBoxSpacingStyles( styles, attributes, 'padding', 'padding' );
	addBoxSpacingStyles( styles, attributes, 'margin', 'margin' );

	return styles;
}

function EcwidProductGridEdit( props ) {
	const attributes = props.attributes;
	const settings = useSettings( 'color.palette', 'typography.fontSizes' );
	const editorSettings = {
		colorPalette: settings[ 0 ],
		fontSizes: settings[ 1 ],
	};
	const blockProps = useBlockProps( {
		className: 'ran-ecwid-shop-teaser-editor alignwide',
		style: getPresentationStyle( attributes, editorSettings ),
	} );
	const refreshingState = useState( false );
	const isRefreshing = refreshingState[ 0 ];
	const setIsRefreshing = refreshingState[ 1 ];
	const previewProductsState = useState( [] );
	const previewProducts = previewProductsState[ 0 ];
	const setPreviewProducts = previewProductsState[ 1 ];
	const previewLoadingState = useState( false );
	const isPreviewLoading = previewLoadingState[ 0 ];
	const setIsPreviewLoading = previewLoadingState[ 1 ];
	const previewMessageState = useState( '' );
	const previewMessage = previewMessageState[ 0 ];
	const setPreviewMessage = previewMessageState[ 1 ];

	function setNumberAttribute( name, value ) {
		const parsed = parseInt( value, 10 );
		props.setAttributes( {
			[ name ]: Number.isNaN( parsed ) ? 0 : parsed,
		} );
	}

	function resetDimensionSettings() {
		props.setAttributes( {
			gridGap: DEFAULT_PRESENTATION_ATTRIBUTES.gridGap,
			imageWidth: DEFAULT_PRESENTATION_ATTRIBUTES.imageWidth,
			imageWidthValue: DEFAULT_PRESENTATION_ATTRIBUTES.imageWidthValue,
			style: getStyleWithoutSpacingValues( attributes, [
				'blockGap',
				'padding',
				'margin',
			] ),
		} );
	}

	function resetImageSettings() {
		props.setAttributes( {
			imageAspectRatio: DEFAULT_PRESENTATION_ATTRIBUTES.imageAspectRatio,
			imageFit: DEFAULT_PRESENTATION_ATTRIBUTES.imageFit,
			imageShape: DEFAULT_PRESENTATION_ATTRIBUTES.imageShape,
		} );
	}

	function resetTypographySettings() {
		props.setAttributes( {
			textAlign: DEFAULT_PRESENTATION_ATTRIBUTES.textAlign,
			textColor: DEFAULT_PRESENTATION_ATTRIBUTES.textColor,
			titleColor: DEFAULT_PRESENTATION_ATTRIBUTES.titleColor,
			descriptionColor: DEFAULT_PRESENTATION_ATTRIBUTES.descriptionColor,
			titleSize: DEFAULT_PRESENTATION_ATTRIBUTES.titleSize,
			titleCustomSize: DEFAULT_PRESENTATION_ATTRIBUTES.titleCustomSize,
			titleFontStyle: DEFAULT_PRESENTATION_ATTRIBUTES.titleFontStyle,
			titleFontWeight: DEFAULT_PRESENTATION_ATTRIBUTES.titleFontWeight,
			titleLineHeight: DEFAULT_PRESENTATION_ATTRIBUTES.titleLineHeight,
			titleTransform: DEFAULT_PRESENTATION_ATTRIBUTES.titleTransform,
			priceSize: DEFAULT_PRESENTATION_ATTRIBUTES.priceSize,
			priceCustomSize: DEFAULT_PRESENTATION_ATTRIBUTES.priceCustomSize,
			priceFontStyle: DEFAULT_PRESENTATION_ATTRIBUTES.priceFontStyle,
			priceFontWeight: DEFAULT_PRESENTATION_ATTRIBUTES.priceFontWeight,
			priceLineHeight: DEFAULT_PRESENTATION_ATTRIBUTES.priceLineHeight,
			priceColor: DEFAULT_PRESENTATION_ATTRIBUTES.priceColor,
		} );
	}

	function refreshProductCache() {
		if ( ! attributes.categoryId || isRefreshing ) {
			return;
		}

		setIsRefreshing( true );
		setIsPreviewLoading( true );

		apiFetch( {
			path: '/ran-ecwid-shop-teaser/v1/ecwid-shop-teaser/refresh',
			method: 'POST',
			data: {
				categoryId: attributes.categoryId,
				limit: attributes.limit || 12,
				showUnavailable: !! attributes.showUnavailable,
				cacheTtl: attributes.cacheTtl || 300,
				staticFallbackEnabled:
					attributes.staticFallbackEnabled !== false,
			},
		} )
			.then( function ( response ) {
				setPreviewProducts( response.products || [] );
				setPreviewMessage( response.message || '' );
			} )
			.catch( function ( error ) {
				setPreviewMessage(
					error && error.message
						? error.message
						: __(
								'Product cache refresh failed.',
								'ran-ecwid-shop-teaser'
						  )
				);
			} )
			.finally( function () {
				setIsRefreshing( false );
				setIsPreviewLoading( false );
			} );
	}

	useEffect(
		function () {
			let isCurrent = true;

			if ( ! attributes.categoryId ) {
				setPreviewProducts( [] );
				setPreviewMessage( '' );
				return function () {
					isCurrent = false;
				};
			}

			setIsPreviewLoading( true );
			setPreviewMessage( '' );

			apiFetch( {
				path: '/ran-ecwid-shop-teaser/v1/ecwid-shop-teaser/preview',
				method: 'POST',
				data: {
					categoryId: attributes.categoryId,
					limit: attributes.limit || 12,
					showUnavailable: !! attributes.showUnavailable,
					cacheTtl: attributes.cacheTtl || 300,
					staticFallbackEnabled:
						attributes.staticFallbackEnabled !== false,
				},
			} )
				.then( function ( response ) {
					if ( ! isCurrent ) {
						return;
					}

					setPreviewProducts( response.products || [] );
					setPreviewMessage( response.message || '' );
				} )
				.catch( function ( error ) {
					if ( ! isCurrent ) {
						return;
					}

					setPreviewProducts( [] );
					setPreviewMessage(
						error && error.message
							? error.message
							: __(
									'Product preview could not be loaded.',
									'ran-ecwid-shop-teaser'
							  )
					);
				} )
				.finally( function () {
					if ( isCurrent ) {
						setIsPreviewLoading( false );
					}
				} );

			return function () {
				isCurrent = false;
			};
		},
		[
			attributes.categoryId,
			attributes.limit,
			attributes.showUnavailable,
			attributes.cacheTtl,
			attributes.staticFallbackEnabled,
			setIsPreviewLoading,
			setPreviewMessage,
			setPreviewProducts,
		]
	);

	return el(
		Fragment,
		null,
		el(
			InspectorControls,
			null,
			el(
				PanelBody,
				{
					title: __( 'Ecwid products', 'ran-ecwid-shop-teaser' ),
					initialOpen: true,
				},
				el( TextControl, {
					label: __( 'Ecwid category ID', 'ran-ecwid-shop-teaser' ),
					type: 'number',
					value: attributes.categoryId || '',
					onChange( value ) {
						setNumberAttribute( 'categoryId', value );
					},
				} ),
				el( RangeControl, {
					label: __( 'Maximum products', 'ran-ecwid-shop-teaser' ),
					value: attributes.limit || 12,
					min: 1,
					max: 24,
					onChange( value ) {
						setNumberAttribute( 'limit', value );
					},
				} ),
				el( ToggleControl, {
					label: __(
						'Show unavailable products',
						'ran-ecwid-shop-teaser'
					),
					checked: !! attributes.showUnavailable,
					onChange() {
						props.setAttributes( {
							showUnavailable: ! attributes.showUnavailable,
						} );
					},
				} ),
				el( RangeControl, {
					label: __( 'Fresh cache seconds', 'ran-ecwid-shop-teaser' ),
					value: attributes.cacheTtl || 300,
					min: 60,
					max: 86400,
					step: 60,
					onChange( value ) {
						setNumberAttribute( 'cacheTtl', value );
					},
				} ),
				el( ToggleControl, {
					label: __(
						'Allow filter-provided fallback products',
						'ran-ecwid-shop-teaser'
					),
					checked: attributes.staticFallbackEnabled !== false,
					onChange() {
						props.setAttributes( {
							staticFallbackEnabled:
								attributes.staticFallbackEnabled === false,
						} );
					},
				} ),
				el(
					Button,
					{
						className: 'ran-ecwid-shop-teaser-editor__reset-button',
						variant: 'secondary',
						disabled: ! attributes.categoryId || isRefreshing,
						isBusy: isRefreshing,
						onClick: refreshProductCache,
					},
					isRefreshing
						? __( 'Refreshing…', 'ran-ecwid-shop-teaser' )
						: __( 'Refresh Ecwid data', 'ran-ecwid-shop-teaser' )
				)
			)
		),
		el(
			InspectorControls,
			{ group: 'styles' },
			el( DimensionsToolsPanel, {
				attributes,
				onReset: resetDimensionSettings,
				setAttributes: props.setAttributes,
			} ),
			el( ImagesToolsPanel, {
				attributes,
				onReset: resetImageSettings,
				setAttributes: props.setAttributes,
			} ),
			el( TypographyToolsPanel, {
				attributes,
				editorSettings,
				onReset: resetTypographySettings,
				setAttributes: props.setAttributes,
			} )
		),
		el(
			'div',
			blockProps,
			el( ProductGridPreview, {
				attributes,
				editorSettings,
				isLoading: isPreviewLoading,
				message: previewMessage,
				products: previewProducts,
			} )
		)
	);
}

registerBlockType( 'ran/ecwid-shop-teaser', {
	icon: PRODUCT_GRID_ICON,
	edit: EcwidProductGridEdit,

	save() {
		return null;
	},
} );

function ProductGridPreview( props ) {
	const attributes = props.attributes;
	const editorSettings = props.editorSettings || {};
	const products = props.products || [];
	const isLoading = props.isLoading;
	const message = props.message || '';
	const previewLabel = attributes.categoryId
		? __( 'Ecwid category preview', 'ran-ecwid-shop-teaser' )
		: __( 'Set an Ecwid category ID', 'ran-ecwid-shop-teaser' );
	const statusLabel = isLoading
		? __( 'Loading Ecwid products', 'ran-ecwid-shop-teaser' )
		: previewLabel;
	let countLabel = __( 'Not set', 'ran-ecwid-shop-teaser' );

	if ( attributes.categoryId ) {
		countLabel = products.length
			? products.length + ' / ' + ( attributes.limit || 12 )
			: '#' + attributes.categoryId;
	}

	return el(
		Fragment,
		null,
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__meta' },
			el( 'span', null, statusLabel ),
			el( 'span', null, countLabel )
		),
		message
			? el(
					'p',
					{ className: 'ran-ecwid-shop-teaser-editor__message' },
					message
			  )
			: null,
		products.length && ! isLoading
			? el( ProductCardGrid, {
					products,
					style: getPresentationStyle( attributes, editorSettings ),
			  } )
			: el( SkeletonGrid, {
					limit: attributes.limit || 3,
					style: getPresentationStyle( attributes, editorSettings ),
			  } )
	);
}

function ImageRatioControl( props ) {
	return el( DisplayToggleControl, {
		label: __( 'Image ratio', 'ran-ecwid-shop-teaser' ),
		options: IMAGE_ASPECT_RATIO_OPTIONS.map( function ( option ) {
			return {
				label: option.label,
				shortLabel: option.value.replace( ' / ', ':' ),
				value: option.value,
			};
		} ),
		value: props.value,
		onChange: props.onChange,
	} );
}

function ImageShapeControl( props ) {
	return el( DisplayToggleControl, {
		label: __( 'Image shape', 'ran-ecwid-shop-teaser' ),
		options: IMAGE_SHAPE_OPTIONS.map( function ( option ) {
			return {
				label: option.label,
				shortLabel: getImageShapeShortLabel( option.value ),
				value: option.value,
			};
		} ),
		value: props.value,
		onChange: props.onChange,
	} );
}

function ImageFitControl( props ) {
	return el( DisplayToggleControl, {
		label: __( 'Image fit', 'ran-ecwid-shop-teaser' ),
		options: IMAGE_FIT_OPTIONS.map( function ( option ) {
			return {
				label: option.label,
				shortLabel:
					option.value === 'cover'
						? __( 'Crop', 'ran-ecwid-shop-teaser' )
						: __( 'Fit', 'ran-ecwid-shop-teaser' ),
				value: option.value,
			};
		} ),
		value: props.value,
		onChange: props.onChange,
	} );
}

function DisplayToggleControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__segmented-field' },
		el(
			'p',
			{
				className:
					'components-base-control__label ran-ecwid-shop-teaser-editor__control-label',
			},
			props.label
		),
		el(
			ToggleGroupControl,
			{
				__next40pxDefaultSize: true,
				hideLabelFromVision: true,
				isBlock: true,
				label: props.label,
				size: '__unstable-large',
				value: props.value,
				onChange: props.onChange,
			},
			props.options.map( function ( option ) {
				return el( ToggleGroupControlOption, {
					'aria-label': option.label,
					key: option.value,
					label: option.shortLabel || option.label,
					value: option.value,
				} );
			} )
		)
	);
}

function DimensionsToolsPanel( props ) {
	const attributes = props.attributes;
	const cardWidthLabel = __( 'Card min width', 'ran-ecwid-shop-teaser' );
	const cardGapLabel = __( 'Card gap', 'ran-ecwid-shop-teaser' );
	const wrapperPaddingLabel = __(
		'Wrapper padding',
		'ran-ecwid-shop-teaser'
	);
	const wrapperMarginLabel = __( 'Wrapper margin', 'ran-ecwid-shop-teaser' );

	return el(
		PanelBody,
		{
			initialOpen: true,
			title: __( 'Dimensions', 'ran-ecwid-shop-teaser' ),
		},
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__dimension-field' },
			el( CardWidthControl, {
				label: cardWidthLabel,
				value: getCardWidthValue( attributes ),
				onChange( value ) {
					if ( ! value ) {
						props.setAttributes( {
							imageWidth:
								DEFAULT_PRESENTATION_ATTRIBUTES.imageWidth,
							imageWidthValue:
								DEFAULT_PRESENTATION_ATTRIBUTES.imageWidthValue,
						} );
						return;
					}

					props.setAttributes( {
						imageWidthValue: value,
					} );
				},
			} )
		),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__dimension-field' },
			el( CardGapControl, {
				label: cardGapLabel,
				value: getLengthControlValue(
					getCardGapValue( attributes ),
					DEFAULT_PRESENTATION_ATTRIBUTES.gridGap + 'rem',
					CARD_SPACING_UNITS
				),
				onChange( value ) {
					if ( ! value ) {
						props.setAttributes( {
							gridGap: DEFAULT_PRESENTATION_ATTRIBUTES.gridGap,
							style: getStyleWithSpacingValue(
								attributes,
								'blockGap',
								''
							),
						} );
						return;
					}

					props.setAttributes( {
						style: getStyleWithSpacingValue(
							attributes,
							'blockGap',
							value
						),
					} );
				},
			} )
		),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__dimension-field' },
			el( LinkedByDefaultBoxControl, {
				__next40pxDefaultSize: true,
				allowReset: false,
				label: wrapperPaddingLabel,
				defaultValues: DEFAULT_WRAPPER_SPACING_VALUES,
				units: WRAPPER_SPACING_UNITS,
				values: getSpacingSideValue( attributes, 'padding' ),
				onChange( value ) {
					if ( ! value ) {
						props.setAttributes( {
							style: getStyleWithSpacingValue(
								attributes,
								'padding',
								''
							),
						} );
						return;
					}

					props.setAttributes( {
						style: getStyleWithSpacingValue(
							attributes,
							'padding',
							value
						),
					} );
				},
			} )
		),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__dimension-field' },
			el( LinkedByDefaultBoxControl, {
				__next40pxDefaultSize: true,
				allowReset: false,
				label: wrapperMarginLabel,
				defaultValues: DEFAULT_WRAPPER_SPACING_VALUES,
				units: WRAPPER_SPACING_UNITS,
				values: getSpacingSideValue( attributes, 'margin' ),
				onChange( value ) {
					if ( ! value ) {
						props.setAttributes( {
							style: getStyleWithSpacingValue(
								attributes,
								'margin',
								''
							),
						} );
						return;
					}

					props.setAttributes( {
						style: getStyleWithSpacingValue(
							attributes,
							'margin',
							value
						),
					} );
				},
			} )
		),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__dimension-field' },
			el(
				Button,
				{
					className: 'ran-ecwid-shop-teaser-editor__reset-button',
					variant: 'secondary',
					onClick: props.onReset,
				},
				__( 'Reset dimensions', 'ran-ecwid-shop-teaser' )
			)
		)
	);
}

function ImagesToolsPanel( props ) {
	const attributes = props.attributes;
	const panelId = 'ran-ecwid-shop-teaser-images';

	return el(
		ToolsPanel,
		{
			dropdownMenuProps: TOOLS_PANEL_DROPDOWN_MENU_PROPS,
			label: __( 'Images', 'ran-ecwid-shop-teaser' ),
			panelId,
			resetAll: props.onReset,
		},
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						getOptionValue(
							attributes.imageAspectRatio,
							IMAGE_ASPECT_RATIO_OPTIONS,
							'3 / 2'
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.imageAspectRatio
					);
				},
				isShownByDefault: false,
				label: __( 'Image ratio', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						imageAspectRatio:
							DEFAULT_PRESENTATION_ATTRIBUTES.imageAspectRatio,
					} );
				},
				panelId,
			},
			el( ImageRatioControl, {
				value: getOptionValue(
					attributes.imageAspectRatio,
					IMAGE_ASPECT_RATIO_OPTIONS,
					'3 / 2'
				),
				onChange( value ) {
					props.setAttributes( {
						imageAspectRatio: value,
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						getOptionValue(
							attributes.imageFit,
							IMAGE_FIT_OPTIONS,
							'cover'
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.imageFit
					);
				},
				isShownByDefault: false,
				label: __( 'Image fit', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						imageFit: DEFAULT_PRESENTATION_ATTRIBUTES.imageFit,
					} );
				},
				panelId,
			},
			el( ImageFitControl, {
				value: getOptionValue(
					attributes.imageFit,
					IMAGE_FIT_OPTIONS,
					'cover'
				),
				onChange( value ) {
					props.setAttributes( {
						imageFit: value,
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						getOptionValue(
							attributes.imageShape,
							IMAGE_SHAPE_OPTIONS,
							'square'
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.imageShape
					);
				},
				isShownByDefault: false,
				label: __( 'Image shape', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						imageShape: DEFAULT_PRESENTATION_ATTRIBUTES.imageShape,
					} );
				},
				panelId,
			},
			el( ImageShapeControl, {
				value: getOptionValue(
					attributes.imageShape,
					IMAGE_SHAPE_OPTIONS,
					'square'
				),
				onChange( value ) {
					props.setAttributes( {
						imageShape: value,
					} );
				},
			} )
		)
	);
}

function CardWidthControl( props ) {
	const parsedValue = getParsedCssLength( props.value, 'rem', 18 );
	const rangeConfig = getCardWidthRangeConfig( parsedValue.unit );

	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__range-unit-field' },
		el( FieldControlLabel, { label: props.label } ),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__range-unit-control' },
			el( UnitControl, {
				__next40pxDefaultSize: true,
				__unstableInputWidth: '88px',
				hideLabelFromVision: true,
				label: props.label,
				min: 0,
				units: CARD_WIDTH_UNITS,
				value: props.value,
				onChange: props.onChange,
			} ),
			el( RangeControl, {
				__next40pxDefaultSize: true,
				hideLabelFromVision: true,
				label: props.label,
				max: rangeConfig.max,
				min: 0,
				step: rangeConfig.step,
				value: parsedValue.quantity,
				withInputField: false,
				onChange( value ) {
					if ( value === undefined ) {
						props.onChange( '' );
						return;
					}

					props.onChange( value + parsedValue.unit );
				},
			} )
		)
	);
}

function CardGapControl( props ) {
	const parsedValue = getParsedCssLength( props.value, 'rem', 1.5 );
	const rangeConfig = getCardSpacingRangeConfig( parsedValue.unit );

	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__range-unit-field' },
		el( FieldControlLabel, { label: props.label } ),
		el(
			'div',
			{ className: 'ran-ecwid-shop-teaser-editor__range-unit-control' },
			el( UnitControl, {
				__next40pxDefaultSize: true,
				__unstableInputWidth: '88px',
				hideLabelFromVision: true,
				label: props.label,
				min: 0,
				units: CARD_SPACING_UNITS,
				value: props.value,
				onChange: props.onChange,
			} ),
			el( RangeControl, {
				__next40pxDefaultSize: true,
				hideLabelFromVision: true,
				label: props.label,
				max: rangeConfig.max,
				min: 0,
				step: rangeConfig.step,
				value: parsedValue.quantity,
				withInputField: false,
				onChange( value ) {
					if ( value === undefined ) {
						props.onChange( '' );
						return;
					}

					props.onChange( value + parsedValue.unit );
				},
			} )
		)
	);
}

function LinkedByDefaultBoxControl( props ) {
	const initialValuesState = useState( EMPTY_BOX_VALUES );
	const currentValues =
		props.values || props.defaultValues || EMPTY_BOX_VALUES;
	const renderedValues = initialValuesState[ 0 ];
	const setRenderedValues = initialValuesState[ 1 ];

	useEffect(
		function () {
			setRenderedValues( currentValues );
		},
		[ currentValues, setRenderedValues ]
	);

	return el( BoxControl, {
		...props,
		values: renderedValues,
		onChange( value ) {
			setRenderedValues( value || EMPTY_BOX_VALUES );
			props.onChange( value );
		},
	} );
}

function TypographyToolsPanel( props ) {
	const attributes = props.attributes;
	const editorSettings = props.editorSettings || {};
	const colorPalette = Array.isArray( editorSettings.colorPalette )
		? editorSettings.colorPalette
		: undefined;
	const titleFontSizePresets = getEditorFontSizePresets(
		editorSettings.fontSizes,
		TITLE_FONT_SIZE_PRESETS
	);
	const priceFontSizePresets = getEditorFontSizePresets(
		editorSettings.fontSizes,
		PRICE_FONT_SIZE_PRESETS
	);
	const titleSizeOptions = getFontSizeOptions( titleFontSizePresets );
	const priceSizeOptions = getFontSizeOptions( priceFontSizePresets );
	const titleSizeValues = getFontSizeValues( titleFontSizePresets );
	const priceSizeValues = getFontSizeValues( priceFontSizePresets );
	const panelId = 'ran-ecwid-shop-teaser-typography';

	function setFontSizeAttributes( newValue, selectedFontSize, config ) {
		const matchedFontSize =
			selectedFontSize && selectedFontSize.slug
				? selectedFontSize
				: config.fontSizes.find( function ( fontSize ) {
						return (
							fontSize &&
							fontSize.slug &&
							String( fontSize.size ) === String( newValue )
						);
				  } );

		if ( matchedFontSize && matchedFontSize.slug ) {
			props.setAttributes( {
				[ config.sizeAttribute ]: matchedFontSize.slug,
				[ config.customAttribute ]: 0,
			} );
			return;
		}

		const parsed = parseFloat( newValue );

		if ( ! newValue || Number.isNaN( parsed ) ) {
			props.setAttributes( {
				[ config.sizeAttribute ]: config.defaultValue,
				[ config.customAttribute ]: 0,
			} );
			return;
		}

		props.setAttributes( {
			[ config.customAttribute ]: Math.min(
				Math.max( parsed, 8 ),
				config.customMax
			),
		} );
	}

	return el(
		ToolsPanel,
		{
			dropdownMenuProps: TOOLS_PANEL_DROPDOWN_MENU_PROPS,
			label: __( 'Typography', 'ran-ecwid-shop-teaser' ),
			panelId,
			resetAll: props.onReset,
		},
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						getOptionValue(
							attributes.textAlign,
							TEXT_ALIGN_OPTIONS,
							'center'
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.textAlign
					);
				},
				isShownByDefault: false,
				label: __( 'Text alignment', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						textAlign: DEFAULT_PRESENTATION_ATTRIBUTES.textAlign,
					} );
				},
				panelId,
			},
			el( TextAlignmentControl, {
				value: getOptionValue(
					attributes.textAlign,
					TEXT_ALIGN_OPTIONS,
					'center'
				),
				onChange( value ) {
					props.setAttributes( {
						textAlign: value || 'center',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						!! attributes.titleColor ||
						!! attributes.descriptionColor ||
						!! attributes.textColor
					);
				},
				isShownByDefault: false,
				label: __( 'Product title color', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						titleColor:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleColor,
						descriptionColor:
							DEFAULT_PRESENTATION_ATTRIBUTES.descriptionColor,
						textColor: DEFAULT_PRESENTATION_ATTRIBUTES.textColor,
					} );
				},
				panelId,
			},
			el( ColorDropdownControl, {
				colors: colorPalette,
				label: __( 'Product title color', 'ran-ecwid-shop-teaser' ),
				value: getColorControlValue(
					attributes.titleColor ||
						attributes.descriptionColor ||
						attributes.textColor ||
						'',
					colorPalette
				),
				onChange( value ) {
					props.setAttributes( {
						titleColor: getSerializableColorValue(
							value,
							colorPalette
						),
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						getOptionValue(
							attributes.titleTransform,
							TITLE_TRANSFORM_OPTIONS,
							'uppercase'
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.titleTransform
					);
				},
				isShownByDefault: false,
				label: __( 'Product title letter case', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						titleTransform:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleTransform,
					} );
				},
				panelId,
			},
			el( TextCaseControl, {
				value: getOptionValue(
					attributes.titleTransform,
					TITLE_TRANSFORM_OPTIONS,
					'uppercase'
				),
				onChange( value ) {
					props.setAttributes( {
						titleTransform: value || 'none',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						!! attributes.titleCustomSize ||
						getOptionValue(
							attributes.titleSize,
							titleSizeOptions,
							DEFAULT_TITLE_FONT_SIZE_PRESET
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.titleSize
					);
				},
				isShownByDefault: false,
				label: __( 'Product title font size', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						titleCustomSize:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleCustomSize,
						titleSize: DEFAULT_PRESENTATION_ATTRIBUTES.titleSize,
					} );
				},
				panelId,
			},
			el( FontSizeControl, {
				fontSizes: titleFontSizePresets,
				label: __( 'Product title font size', 'ran-ecwid-shop-teaser' ),
				value: getFontSizeControlValue( {
					customMax: 96,
					customValue: attributes.titleCustomSize || 0,
					fallbackSize: '1.25rem',
					sizeValues: titleSizeValues,
					value: getOptionValue(
						attributes.titleSize,
						titleSizeOptions,
						DEFAULT_TITLE_FONT_SIZE_PRESET
					),
				} ),
				onChange( newValue, selectedFontSize ) {
					setFontSizeAttributes( newValue, selectedFontSize, {
						customAttribute: 'titleCustomSize',
						customMax: 96,
						defaultValue: DEFAULT_PRESENTATION_ATTRIBUTES.titleSize,
						fontSizes: titleFontSizePresets,
						sizeAttribute: 'titleSize',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						!! attributes.titleFontStyle ||
						!! attributes.titleFontWeight
					);
				},
				isShownByDefault: false,
				label: __( 'Product title font weight', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						titleFontStyle:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleFontStyle,
						titleFontWeight:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleFontWeight,
					} );
				},
				panelId,
			},
			el( FontWeightControl, {
				fontStyle: attributes.titleFontStyle || undefined,
				fontWeight: attributes.titleFontWeight || undefined,
				label: __( 'Product title font weight', 'ran-ecwid-shop-teaser' ),
				onChange( value ) {
					props.setAttributes( {
						titleFontStyle: value.fontStyle || '',
						titleFontWeight: value.fontWeight || '',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return !! attributes.titleLineHeight;
				},
				isShownByDefault: false,
				label: __( 'Product title line height', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						titleLineHeight:
							DEFAULT_PRESENTATION_ATTRIBUTES.titleLineHeight,
					} );
				},
				panelId,
			},
			el( LineHeightField, {
				label: __( 'Product title line height', 'ran-ecwid-shop-teaser' ),
				value: attributes.titleLineHeight || undefined,
				onChange( value ) {
					props.setAttributes( {
						titleLineHeight: getLineHeightAttributeValue( value ),
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return !! attributes.priceColor || !! attributes.textColor;
				},
				isShownByDefault: false,
				label: __( 'Pricing color', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						priceColor: DEFAULT_PRESENTATION_ATTRIBUTES.priceColor,
						textColor: DEFAULT_PRESENTATION_ATTRIBUTES.textColor,
					} );
				},
				panelId,
			},
			el( ColorDropdownControl, {
				colors: colorPalette,
				label: __( 'Pricing color', 'ran-ecwid-shop-teaser' ),
				value: getColorControlValue(
					attributes.priceColor || attributes.textColor || '',
					colorPalette
				),
				onChange( value ) {
					props.setAttributes( {
						priceColor: getSerializableColorValue(
							value,
							colorPalette
						),
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						!! attributes.priceCustomSize ||
						getOptionValue(
							attributes.priceSize,
							priceSizeOptions,
							DEFAULT_PRICE_FONT_SIZE_PRESET
						) !== DEFAULT_PRESENTATION_ATTRIBUTES.priceSize
					);
				},
				isShownByDefault: false,
				label: __( 'Pricing font size', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						priceCustomSize:
							DEFAULT_PRESENTATION_ATTRIBUTES.priceCustomSize,
						priceSize: DEFAULT_PRESENTATION_ATTRIBUTES.priceSize,
					} );
				},
				panelId,
			},
			el( FontSizeControl, {
				fontSizes: priceFontSizePresets,
				label: __( 'Pricing font size', 'ran-ecwid-shop-teaser' ),
				value: getFontSizeControlValue( {
					customMax: 64,
					customValue: attributes.priceCustomSize || 0,
					fallbackSize: '0.875rem',
					sizeValues: priceSizeValues,
					value: getOptionValue(
						attributes.priceSize,
						priceSizeOptions,
						DEFAULT_PRICE_FONT_SIZE_PRESET
					),
				} ),
				onChange( newValue, selectedFontSize ) {
					setFontSizeAttributes( newValue, selectedFontSize, {
						customAttribute: 'priceCustomSize',
						customMax: 64,
						defaultValue: DEFAULT_PRESENTATION_ATTRIBUTES.priceSize,
						fontSizes: priceFontSizePresets,
						sizeAttribute: 'priceSize',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return (
						!! attributes.priceFontStyle ||
						!! attributes.priceFontWeight
					);
				},
				isShownByDefault: false,
				label: __( 'Pricing font weight', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						priceFontStyle:
							DEFAULT_PRESENTATION_ATTRIBUTES.priceFontStyle,
						priceFontWeight:
							DEFAULT_PRESENTATION_ATTRIBUTES.priceFontWeight,
					} );
				},
				panelId,
			},
			el( FontWeightControl, {
				fontStyle: attributes.priceFontStyle || undefined,
				fontWeight: attributes.priceFontWeight || undefined,
				label: __( 'Pricing font weight', 'ran-ecwid-shop-teaser' ),
				onChange( value ) {
					props.setAttributes( {
						priceFontStyle: value.fontStyle || '',
						priceFontWeight: value.fontWeight || '',
					} );
				},
			} )
		),
		el(
			ToolsPanelItem,
			{
				hasValue() {
					return !! attributes.priceLineHeight;
				},
				isShownByDefault: false,
				label: __( 'Pricing line height', 'ran-ecwid-shop-teaser' ),
				onDeselect() {
					props.setAttributes( {
						priceLineHeight:
							DEFAULT_PRESENTATION_ATTRIBUTES.priceLineHeight,
					} );
				},
				panelId,
			},
			el( LineHeightField, {
				label: __( 'Pricing line height', 'ran-ecwid-shop-teaser' ),
				value: attributes.priceLineHeight || undefined,
				onChange( value ) {
					props.setAttributes( {
						priceLineHeight: getLineHeightAttributeValue( value ),
					} );
				},
			} )
		)
	);
}

function TextAlignmentControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el(
			'p',
			{
				className:
					'components-base-control__label ran-ecwid-shop-teaser-editor__control-label',
			},
			__( 'Text alignment', 'ran-ecwid-shop-teaser' )
		),
		el(
			ToggleGroupControl,
			{
				__next40pxDefaultSize: true,
				hideLabelFromVision: true,
				isBlock: true,
				label: __( 'Text alignment', 'ran-ecwid-shop-teaser' ),
				size: '__unstable-large',
				value: props.value,
				onChange: props.onChange,
			},
			TEXT_ALIGN_OPTIONS.map( function ( option ) {
				return el( ToggleGroupControlOption, {
					'aria-label': option.label,
					key: option.value,
					label: el( 'span', {
						'aria-hidden': 'true',
						className:
							'ran-ecwid-shop-teaser-editor__align-icon is-align-' +
							option.value,
					} ),
					value: option.value,
				} );
			} )
		)
	);
}

function ColorDropdownControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el( Dropdown, {
			className: 'ran-ecwid-shop-teaser-editor__color-dropdown',
			contentClassName: 'ran-ecwid-shop-teaser-editor__color-popover',
			popoverProps: {
				placement: 'left-start',
				offset: 36,
				shift: true,
			},
			renderToggle( dropdownProps ) {
				return el(
					Button,
					{
						'aria-expanded': dropdownProps.isOpen,
						className:
							'block-editor-panel-color-gradient-settings__dropdown ran-ecwid-shop-teaser-editor__color-button',
						onClick: dropdownProps.onToggle,
					},
					el( ColorIndicator, {
						className:
							'block-editor-panel-color-gradient-settings__color-indicator',
						colorValue: props.value || undefined,
					} ),
					el(
						'span',
						{
							className:
								'block-editor-panel-color-gradient-settings__color-name',
						},
						props.label
					)
				);
			},
			renderContent() {
				return el( ColorPalette, {
					clearable: true,
					colors: props.colors,
					onChange: props.onChange,
					value: props.value,
				} );
			},
		} )
	);
}

function TextCaseControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el(
			ToggleGroupControl,
			{
				__next40pxDefaultSize: true,
				hideLabelFromVision: false,
				isBlock: true,
				label: __( 'Letter case', 'ran-ecwid-shop-teaser' ),
				size: '__unstable-large',
				value: props.value,
				onChange( value ) {
					props.onChange( value || 'none' );
				},
			},
			TITLE_TRANSFORM_OPTIONS.map( function ( option ) {
				return el( ToggleGroupControlOption, {
					'aria-label': option.label,
					key: option.value,
					label: option.shortLabel || option.label,
					value: option.value,
				} );
			} )
		)
	);
}

function FontSizeControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el( FieldControlLabel, { label: props.label } ),
		el( FontSizePicker, {
			fontSizes: props.fontSizes,
			label: props.label,
			size: '__unstable-large',
			units: [ 'px' ],
			value: props.value,
			withReset: false,
			withSlider: true,
			onChange: props.onChange,
		} )
	);
}

function FontWeightControl( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el( FieldControlLabel, { label: props.label } ),
		el( FontAppearanceControl, {
			hasFontStyles: false,
			hasFontWeights: true,
			label: props.label,
			size: '__unstable-large',
			value: {
				fontStyle: props.fontStyle,
				fontWeight: props.fontWeight,
			},
			onChange: props.onChange,
		} )
	);
}

function LineHeightField( props ) {
	return el(
		'div',
		{ className: 'ran-ecwid-shop-teaser-editor__typography-field' },
		el( FieldControlLabel, { label: props.label } ),
		el( LineHeightControl, {
			__unstableInputWidth: 'auto',
			label: props.label,
			size: '__unstable-large',
			value: props.value,
			onChange: props.onChange,
		} )
	);
}

function FieldControlLabel( props ) {
	if ( ! props.label ) {
		return null;
	}

	return el(
		'p',
		{
			className:
				'components-base-control__label ran-ecwid-shop-teaser-editor__control-label',
		},
		props.label
	);
}

function getFontSizeControlValue( props ) {
	const customSize = getCustomPixelSize( props.customValue, props.customMax );

	return (
		customSize ||
		props.sizeValues[ props.value ] ||
		getFontSizePresetCssValue( props.value, props.fallbackSize )
	);
}

function ProductCardGrid( props ) {
	return el(
		'div',
		{
			className: 'ran-ecwid-shop-teaser',
			style: props.style,
		},
		props.products.map( function ( product ) {
			return el(
				'article',
				{
					className: 'ran-ecwid-shop-teaser-card',
					key: product.id || product.url || product.name,
				},
				el(
					'span',
					{
						className: 'ran-ecwid-shop-teaser-card__media',
					},
					el( 'img', {
						src: product.image_url,
						alt: product.image_alt || product.name,
						loading: 'lazy',
					} )
				),
				el(
					'h3',
					{
						className: 'ran-ecwid-shop-teaser-card__title',
					},
					product.name
				),
				product.price
					? el(
							'p',
							{
								className: 'ran-ecwid-shop-teaser-card__price',
							},
							product.price
					  )
					: null
			);
		} )
	);
}

function SkeletonGrid( props ) {
	const items = getPreviewItems( props.limit );

	return el(
		'div',
		{
			className: 'ran-ecwid-shop-teaser ran-ecwid-shop-teaser--skeleton',
			style: props.style,
		},
		items.map( function ( _, index ) {
			return el(
				'article',
				{
					className:
						'ran-ecwid-shop-teaser-card ran-ecwid-shop-teaser-card--skeleton',
					key: index,
				},
				el( 'span', {
					className: 'ran-ecwid-shop-teaser-card__media',
					'aria-hidden': 'true',
				} ),
				el( 'span', {
					className: 'ran-ecwid-shop-teaser-card__title',
					'aria-hidden': 'true',
				} ),
				el( 'span', {
					className: 'ran-ecwid-shop-teaser-card__price',
					'aria-hidden': 'true',
				} )
			);
		} )
	);
}
