import * as fs from "fs";
//import { format } from "prettier";
//const prettier = require("prettier");
import { resolve, dirname } from "path";

//require("./Main.elm");

module.exports = (Elm: any) => {
  //console.log(process.cwd());
  //console.log(process.env.npm_lifecycle_event);
  //console.log(process.argv);
  //const target = resolve(process.env.SRC_PATH!);
  //console.log(process.env.EXEC_PATH, process.env.SRC_PATH);
  const target = resolve(process.env.EXEC_PATH!, process.env.SRC_PATH!);
  //console.log(target);
  const src = fs.readFileSync(target, "utf8");
  const app = Elm.Main.init({ flags: { src } });
  app.ports.log.subscribe(async (txt: string) => {
    //fs.writeFileSync("./final.json", txt);
    const ast = JSON.parse(txt);
    try {
      //console.log(ast);
      const tps = parseTypes(ast);
      //console.log(tps);
      const res = parseAST(ast);
      //const good = JSON.stringify(res, null, 2);
      const prod = buildTypes(res, tps);
      const writeTo = resolve(dirname(target), "ports.d.ts");
      fs.writeFileSync(
        writeTo,
        //await prettier.format(prod, { parser: "typescript" })
        prod
      );
      console.log("success!", writeTo);
    } catch (e) {
      //console.log(txt);
      console.error(e);
      console.log("bad");
    }
  });
};

function buildTypes(xs: any[], types_: [string, string][]): string {
  const types = types_.map((x) => x[1]).join("\n\n");
  const names = types_.map((x) => x[0]).join(", ");
  //name type argument
  const wall = xs
    .map((x) => {
      const gg =
        x.type === "IN" ? `PortIn<${x.argument}>` : `PortOut<${x.argument}>`;
      return `${x.name}: ${gg};`;
    })
    .join("\n  ");

  return `interface ElmApp {
  ports: Ports;
}
${types ? "\n" + types + "\n" : ""}
interface Ports {
  ${wall}
}

interface PortOut<T> {
  subscribe: (_: (_: T) => void) => void;
}

interface PortIn<T> {
  send: (_: T) => void;
}

${types.length === 0 ? "export { ElmApp }" : `export { ElmApp, ${names} }`};
`;
}

//walletTimeout: PortIn;
//walletCb: PortIn;
//disconnectIn: PortIn;
//connectCb: PortIn;

//close: PortOut;
//connect: PortOut;
//disconnect: PortOut;

function parseTypes(ast: any): [string, string][] {
  return ast.declarations
    .filter((dec: any) => dec.value.type === "typeAlias")
    .map((declaration: any) => {
      const name = declaration.value.typeAlias.name.value;
      const strct = _tppParse(declaration.value.typeAlias.typeAnnotation.value);
      return [name, `interface ${name} ${strct}`];
    });
}

function parseAST(ast: any): any {
  //console.log(ast);
  if (!ast) {
    return "nah";
  }
  return ast.declarations
    .filter((dec: any) => dec.value.type === "port")
    .map((declaration: any) => {
      //const {
      //value: {
      //port: {
      //name: { value: name },
      //typeAnnotation: {
      //value: {
      //function: {
      //left: { value: left },
      //right: { value: right },
      //},
      //},
      //},
      //},
      //},
      //} = declaration;

      const name = declaration.value.port.name.value;
      //console.log(name);

      const resArg =
        declaration.value.port.typeAnnotation?.value?.function?.right?.value?.typed?.moduleNameAndName?.value?.name?.toLowerCase();
      const type = resArg === "cmd" ? "OUT" : "IN";
      const argPre =
        type === "OUT"
          ? declaration.value.port.typeAnnotation?.value?.function?.left?.value
          : declaration.value.port.typeAnnotation?.value?.function?.left?.value
              ?.function?.left?.value;

      //const getRes = (x: any) =>
      //x.type === "unit"
      //? "()"
      //: x.type === "tupled"
      //? "Tuple"
      //: x.type === "record"
      //? "Record"
      //: x.typed?.moduleNameAndName?.value?.name;

      //const argRes = getRes(argPre);
      //argPre.type === "unit"
      //? "()"
      //: argPre.type === "tupled"
      //? "Tuple"
      //: argPre.typed?.moduleNameAndName?.value?.name;

      //console.log("#######", _tppParse(argPre));
      //console.log(argRes);
      //const argie = argParse(argRes);
      //const suff =
      //argRes === "Maybe"
      //? " " + argPre.typed.args[0].value.typed.moduleNameAndName.value.name
      //: "";
      //const type = right?.typed?.name ? right.typed.name.toLowerCase() : "";

      //let argument = "";
      //if (left?.value?.typed) {
      //if (left.value.typed.moduleNameAndName.name === "Maybe") {
      //argument = `Maybe ${left.value.typed.args[0].value.typed.moduleNameAndName.name}`;
      //} else {
      //argument = left.value.typed.moduleNameAndName.name;
      //}
      //} else {
      //argument = left?.value?.type || "";
      //}

      return { name, type, argument: _tppParse(argPre) };
    });
}

function _tppParse(pm: any) {
  switch (pm.type) {
    case "unit": {
      return "null";
    }
    case "tupled": {
      const xs = pm.tupled.values
        .map((v: any) => _tppParse(v.value))
        .join(", ");
      return "[" + xs + "]";
    }
    case "record": {
      const xs = pm.record.value
        .map((v: any) => {
          //const val = argParse(getRes(v.value));
          const key = v.value.name.value;
          const val = _tppParse(v.value.typeAnnotation.value);
          return `${key}: ${val}`;
        })
        .join("; ");
      return "{ " + xs + " }";
    }
    default: {
      const key = pm.typed?.moduleNameAndName?.value?.name;
      switch (key) {
        case "String": {
          return "string";
        }
        case "Float": {
          return "number";
        }
        case "Int": {
          return "number";
        }
        case "Bool": {
          return "boolean";
        }
        case "Value": {
          return "any";
        }
        case "Maybe": {
          //console.log(pm.typed.args[0]);
          //console.log(_tppParse(pm.typed.args[0].value));
          const val: any = _tppParse(pm.typed.args[0].value);
          return `${val} | null`;
        }
        case "List": {
          const val: any = _tppParse(pm.typed.args[0].value);
          return `${val}[]`;
        }
        default: {
          console.log("loose type:", key);
          return key;
          //throw new Error(key);
        }
      }
    }
  }
}

//const argParse = (pm: any) => {
//switch (pm) {
//case "String": {
//return "string";
//}
//case "Float": {
//return "number";
//}
//case "Int": {
//return "number";
//}
//case "Bool": {
//return "boolean";
//}
//case "()": {
//return "null";
//}
//case "Tuple": {
//const xs = argPre.tupled.values
//.map((v: any) => argParse(getRes(v.value)))
//.join(", ");
//return "[" + xs + "]";
//}
//case "Record": {
//const xs = argPre.record.value
//.map((v: any) => {
////const val = argParse(getRes(v.value));
//const key = v.value.name.value;
//const val = argParse(getRes(v.value.typeAnnotation.value));
//return `${key}: ${val}`;
//})
//.join("; ");
//return "{ " + xs + " }";
//}
//case "Maybe": {
//const val: any = argParse(
//argPre.typed.args[0].value.typed.moduleNameAndName.value.name
//);
//return `${val} | null`;
//}
//case "List": {
//const val: any = argParse(
//argPre.typed.args[0].value.typed.moduleNameAndName.value.name
//);
//return `${val}[]`;
//}
//default: {
//return "bad: " + pm;
//}
//}
//};
