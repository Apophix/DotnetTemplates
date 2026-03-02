//  @ts-check

import { tanstackConfig } from "@tanstack/eslint-config";

export default [
	...tanstackConfig,
	{
		rules: {
			"@typescript-eslint/array-type": "off",
			"no-unused-vars": "off",
			"@typescript-eslint/no-explicit-any": "off",
			"@typescript-eslint/no-non-null-assertion": "off",
			"import/consistent-type-specifier-style": "off",
			"sort-imports": "off",
		},
	},
];
