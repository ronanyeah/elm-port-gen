import { readFileSync, writeFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { ElmApp, Flags } from "./ports";
import { compileToString } from "@ronanyeah/node-elm-compiler-2";

const cwd = process.cwd();

(async () => {
  const elmJson = resolve(cwd, "elm.json");
  if (!existsSync(elmJson)) {
    return console.error("elm.json not present");
  }
  const srcFolder = resolve(cwd, "./src");
  if (!existsSync(srcFolder)) {
    return console.error("./src not present");
  }

  const filename = process.argv[2];
  if (!filename) {
    return console.error("no filename");
  }

  if (!filename.endsWith(".elm")) {
    return console.error("not an elm file");
  }

  const generatorElm = resolve(__dirname, "../src/Main.elm");

  const result = await compileToString(generatorElm, {
    pathToElm: resolve(__dirname, "../node_modules/.bin/elm"),
    cwd: resolve(__dirname, ".."),
    // false to enable Debug.log
    optimize: true,
  });

  if (result.status === "error") {
    console.error(result.stderr);
    return process.exit(result.exitCode);
  }

  const Elm = new Function(`
  ${result.output}
  return this.Elm;
`)();
  const target = resolve(cwd, filename);

  if (!existsSync(target)) {
    return console.error("not present: " + target);
  }

  console.log("Source file:", target);
  const src = readFileSync(target, "utf8");

  const flags: Flags = { src };
  const app: ElmApp = Elm.Main.init({ flags });

  app.ports.successCb.subscribe((txt) => {
    const outDir = dirname(target);
    const writeTo = resolve(outDir, "ports.ts");
    writeFileSync(writeTo, txt);
    console.log("Written to:", writeTo);

    const elmDts = resolve(outDir, "elm.d.ts");
    writeFileSync(
      elmDts,
      `declare module "*.elm" {
  const elm: {
    init: (options: {
      node: HTMLElement;
      flags: import("./ports").Flags;
    }) => import("./ports").ElmApp;
  };
  export default elm;
}
`,
    );
    console.log("Written to:", elmDts);
  });

  app.ports.errorCb.subscribe((txt) => {
    console.error("Error:", txt);
  });

  app.ports.readFiles.subscribe((paths) => {
    const fileData = paths.map((path) => ({
      path,
      content: readFileSync(resolve(cwd, "./src", path + ".elm"), "utf8"),
    }));
    app.ports.typesIn.send(fileData);
  });
})();
