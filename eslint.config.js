import typescript_eslint_parser from "@typescript-eslint/parser";
import typescript_eslint from "@typescript-eslint/eslint-plugin";
import prettier_recommended from "eslint-plugin-prettier/recommended";

export default [
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: typescript_eslint_parser,
      parserOptions: {
        project: true,
      },
    },
    plugins: {
      "@typescript-eslint": typescript_eslint,
    },
    rules: {
      "@typescript-eslint/no-floating-promises": "off",
    },
  },
  prettier_recommended,
];
