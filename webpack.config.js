const { resolve } = require("path");
const webpack = require("webpack");

module.exports = () => {
  const loaderConfig = {
    loader: "elm-webpack-loader",
    options: {
      debug: false,
      optimize: false,
      cwd: __dirname,
    },
  };

  return {
    target: "node",
    mode: "development",
    entry: "./src/index.ts",
    stats: "errors-warnings",
    module: {
      rules: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: [{ loader: "elm-reloader" }, loaderConfig],
        },
        {
          test: /\.ts$/,
          use: "ts-loader",
          exclude: /node_modules/,
        },
      ],
    },
    resolve: {
      extensions: [".ts", ".js"],
    },
    plugins: [new webpack.NoEmitOnErrorsPlugin()],
  };
};
