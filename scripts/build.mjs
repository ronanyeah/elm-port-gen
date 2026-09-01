import { execSync } from "node:child_process";

try {
  execSync("elm make src/Main.elm --output=/dev/null", {
    stdio: "inherit",
  });
  execSync("tsc --noEmit", { stdio: "inherit" });
} catch {
  //
}
