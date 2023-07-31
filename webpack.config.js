const { resolve } = require("path");
const webpack = require("webpack");

const publicFolder = resolve("./dist");

module.exports = (env) => {
  const devMode = Boolean(env.WEBPACK_SERVE);

  const loaderConfig = {
    loader: "elm-webpack-loader",
    options: {
      debug: false,
      optimize: !devMode,
      cwd: __dirname,
    },
  };

  const elmLoader = devMode
    ? [{ loader: "elm-reloader" }, loaderConfig]
    : [loaderConfig];

  return {
    target: "node",
    mode: devMode ? "development" : "production",
    entry: "./src/index.ts",
    //entry: "./src/Main.elm",
    output: {
      publicPath: "/",
      path: publicFolder,
      filename: "lib.js",
      libraryTarget: "commonjs2",
    },
    stats: devMode ? "errors-warnings" : "normal",
    infrastructureLogging: {
      level: "warn",
    },
    module: {
      rules: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: elmLoader,
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
