const fs = require("fs");
const path = require("path");
const luamin = require("luamin");

const ofRoot = path.resolve(__dirname, "..");
const distDir = path.join(ofRoot, "dist");
const inputPath = path.join(distDir, "HOC_NOC.release.lua");
const outputPath = path.join(distDir, "HOC_NOC.release.obf.lua");

function ensureInput() {
  if (!fs.existsSync(inputPath)) {
    throw new Error(
      "Arquivo de entrada nao encontrado. Rode npm run build dentro de OFUSCAMENTO antes da ofuscacao."
    );
  }
}

function banner() {
  const version = process.env.RELEASE_VERSION || process.env.GITHUB_REF_NAME || "dev-local";
  const date = new Date().toISOString();
  return `-- HOC NOC obfuscated build | version=${version} | generated=${date}\\n`;
}

function main() {
  ensureInput();
  const src = fs.readFileSync(inputPath, "utf8");
  const minified = luamin.minify(src);
  fs.writeFileSync(outputPath, banner() + minified + "\n", "utf8");

  console.log("[OFUSCAMENTO] Ofuscacao concluida:");
  console.log(` - ${outputPath}`);
}

main();
