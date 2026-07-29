import { spawn, spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";

const host = "127.0.0.1";
const port = "3100";
const baseUrl = `http://${host}:${port}`;
const nextCli = "node_modules/next/dist/bin/next";
const playwrightCli = "node_modules/@playwright/test/cli.js";
const testArguments = process.argv.slice(2);

async function waitForServer(child) {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      throw new Error("Lokalni test-server se neočekivano zaustavio.");
    }
    try {
      const response = await fetch(baseUrl);
      if (response.ok) return;
    } catch {
      // Server se još pokreće.
    }
    await delay(500);
  }
  throw new Error("Lokalni test-server nije pokrenut u predviđenom roku.");
}

function stopServer(child) {
  if (child.exitCode !== null) return;
  if (process.platform === "win32") {
    spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], {
      stdio: "ignore"
    });
  } else {
    child.kill("SIGTERM");
  }
}

const server = spawn(
  process.execPath,
  [nextCli, "start", "--hostname", host, "--port", port],
  { stdio: ["ignore", "ignore", "inherit"] }
);

let exitCode = 1;
try {
  await waitForServer(server);
  const tests = spawnSync(
    process.execPath,
    [playwrightCli, "test", ...testArguments],
    { stdio: "inherit" }
  );
  exitCode = tests.status ?? 1;
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
} finally {
  stopServer(server);
}

process.exit(exitCode);
