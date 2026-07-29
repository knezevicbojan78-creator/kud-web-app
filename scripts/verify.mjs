import { spawnSync } from "node:child_process";

const npmCommand = process.platform === "win32" ? "npm.cmd" : "npm";
const steps = [
  ["run", "check:project"],
  ["run", "check:migrations"],
  ["run", "typecheck"],
  ["run", "build"],
  ["run", "test:e2e:smoke"]
];

for (const args of steps) {
  const label = args.slice(1).join(" ");
  console.log(`\n=== ${label} ===`);
  const result = spawnSync(npmCommand, args, {
    stdio: "inherit",
    shell: process.platform === "win32"
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

console.log("\nSve lokalne provere su uspešno završene.");
