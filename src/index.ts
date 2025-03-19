import { readFileSync, writeFileSync } from "fs";
import { compileToString } from "node-elm-compiler";
import { resolve, dirname } from "path";

// Uncomment for 'webpack serve' typechecking
//require("./Main.elm");

(async () => {
  const filename = process.argv[2];
  if (!filename) {
    return console.log("no filename");
  }
  if (!filename.endsWith(".elm")) {
    return console.log("not an elm file");
  }
  const main = resolve(__dirname, "../src/Main.elm");

  const compiled = await compileToString(main, {
    pathToElm: resolve(__dirname, "../node_modules/.bin/elm"),
    cwd: resolve(__dirname, ".."),
    optimize: true,
  });

  const Elm = new Function(`
  ${compiled}
  return this.Elm;
`)();
  const cwd = process.cwd();
  const target = resolve(cwd, filename);

  console.log("Source file:", target);
  const src = readFileSync(target, "utf8");
  const app = Elm.Main.init({ flags: { src } });
  app.ports.successCb.subscribe((txt: string) => {
    const writeTo = resolve(dirname(target), "ports.ts");
    writeFileSync(writeTo, txt);
    console.log("Written to:", writeTo);
  });
  app.ports.errorCb.subscribe((txt: string) => {
    console.log("Error:", txt);
  });
})();
