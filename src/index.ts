import { readFileSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";

// Uncomment for 'webpack serve' typechecking
//require("./Main.elm");

module.exports = (Elm: any) => {
  const cwd = process.env.EXEC_PATH;
  if (!cwd) {
    throw Error("missing EXEC_PATH");
  }
  const file = process.env.SRC_PATH;
  if (!file) {
    throw Error("missing SRC_PATH");
  }
  const target = resolve(cwd, file);
  const src = readFileSync(target, "utf8");
  const app = Elm.Main.init({ flags: { src } });
  app.ports.export.subscribe((txt: string) => {
    const writeTo = resolve(dirname(target), "ports.ts");
    writeFileSync(writeTo, txt);
    console.log("gen complete:", writeTo);
  });
};
