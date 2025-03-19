// Adapted from:
// https://github.com/rtfeldman/node-elm-compiler/blob/master/src/index.ts

import { exec, ExecOptions } from "child_process";
import { promises as fs } from "fs";
import * as path from "path";
import * as os from "os";
import { promisify } from "util";

// Promisify exec for a cleaner functional approach
const execPromise = promisify(exec);

/**
 * Options for the Elm compiler
 */
interface ElmCompilerOptions {
  cwd: string;
  pathToElm: string;
  optimize: boolean;
  //debug?: boolean;
}

/**
 * Create a temporary file for output
 */
async function createTempFile(): Promise<string> {
  const tmpDir = os.tmpdir();
  const randomName = Math.random().toString(36).substring(2, 10);
  const tempFilePath = path.join(tmpDir, `elm-output-${randomName}.js`);

  // Touch the file to create it
  await fs.writeFile(tempFilePath, "");

  return tempFilePath;
}

/**
 * Convert options to compiler arguments
 */
function compilerArgsFromOptions(options: ElmCompilerOptions): string[] {
  const args: string[] = [];

  //if (options.debug) {
  //args.push("--debug");
  //}

  if (options.optimize) {
    args.push("--optimize");
  }

  return args;
}

/**
 * Read file and clean up afterwards
 */
async function readAndCleanup(filePath: string) {
  const content = await fs.readFile(filePath, { encoding: "utf8" });
  // Schedule cleanup but don't wait for it
  fs.unlink(filePath).catch((err) => {
    console.error("unlink fail: " + err);
  });
  return content;
}

function handleCompilerError(
  err: Error & { code?: string },
  pathToElm: string
): Error {
  if (err.code === "ENOENT") {
    return new Error(
      `Could not find Elm compiler "${pathToElm}". Is it installed?`
    );
  }

  if (err.code === "EACCES") {
    return new Error(
      `Elm compiler "${pathToElm}" did not have permission to run. Do you need to give it executable permissions?`
    );
  }

  return new Error(
    `Error attempting to run Elm compiler "${pathToElm}":\n${err.message}`
  );
}

/**
 * Compile Elm code to a JS string
 */
export async function compileToString(
  sources: string | string[],
  options: ElmCompilerOptions
): Promise<string> {
  const tempFilePath = await createTempFile();

  //try {
  // use global elm
  //const elmBinary = options.pathToElm || "elm";
  const elmBinary = options.pathToElm;

  const preparedSources = typeof sources === "string" ? [sources] : sources;
  const compilerArgs = [
    "make",
    ...preparedSources,
    "--output",
    tempFilePath,
    ...compilerArgsFromOptions(options),
  ];

  const processOpts: ExecOptions = {
    cwd: options.cwd,
  };

  const fullCommand = `${elmBinary} ${compilerArgs.join(" ")}`;
  return execPromise(fullCommand, processOpts)
    .then(() => readAndCleanup(tempFilePath))
    .catch((err) => {
      fs.unlink(tempFilePath).catch(() => {});
      throw handleCompilerError(err, elmBinary);
    });
}
