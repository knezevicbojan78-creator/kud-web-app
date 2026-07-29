import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const trackedFiles = execFileSync(
  "git",
  ["ls-files", "--cached", "--others", "--exclude-standard"],
  {
  encoding: "utf8"
  }
)
  .split(/\r?\n/)
  .filter(Boolean);

const errors = [];
const forbiddenPaths = [
  /(^|\/)\.env($|\.)/i,
  /(^|\/)node_modules(\/|$)/i,
  /(^|\/)\.next(\/|$)/i,
  /(^|\/)(coverage|playwright-report|test-results)(\/|$)/i,
  /\.tsbuildinfo$/i
];

for (const file of trackedFiles) {
  if (file === ".env.example") continue;
  if (forbiddenPaths.some((pattern) => pattern.test(file))) {
    errors.push(`${file}: fajl ne treba da bude sačuvan u Git istoriji`);
    continue;
  }

  if (!/\.(?:[cm]?[jt]sx?|json|md|sql|ya?ml|txt|example)$/i.test(file)) {
    continue;
  }

  const contents = readFileSync(file, "utf8");
  if (/^(?:<{7}|={7}|>{7})(?:\s|$)/m.test(contents)) {
    errors.push(`${file}: pronađena je nerešena Git oznaka konflikta`);
  }

  const secretPatterns = [
    /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/,
    /(?:RESEND_API_KEY|SUPABASE_SERVICE_ROLE_KEY)\s*=\s*["']?\S{8,}/,
    /postgres(?:ql)?:\/\/[^:\s]+:[^@\s]+@/i
  ];
  if (secretPatterns.some((pattern) => pattern.test(contents))) {
    errors.push(`${file}: pronađena je vrednost koja liči na tajni podatak`);
  }
}

if (errors.length) {
  console.error("Provera projekta nije prošla:");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Provera projekta je prošla (${trackedFiles.length} projektnih fajlova).`);
