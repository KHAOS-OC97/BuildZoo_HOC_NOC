const fs = require("fs");
const path = require("path");

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

function encodeSource(src) {
  const encoded = [];
  for (let i = 0; i < src.length; i += 1) {
    const byte = src.charCodeAt(i) & 0xff;
    encoded.push((byte + 17) % 256);
  }
  return encoded;
}

function buildObfuscatedWrapper(encodedBytes) {
  const payload = encodedBytes.join(",");
  return [
    "local __p={" + payload + "}",
    "local function __d(t)",
    "  if type(t)~='table' then error('[HOC NOC] payload invalido') end",
    "  local _string = string",
    "  local _table = table",
    "  if type(_string)~='table' or type(_string.char)~='function' then error('[HOC NOC] runtime sem string.char') end",
    "  if type(_table)~='table' or type(_table.concat)~='function' then error('[HOC NOC] runtime sem table.concat') end",
    "  local o={} ",
    "  for i=1,#t do",
    "    local v=t[i]",
    "    if type(v)~='number' then error('[HOC NOC] byte invalido no payload') end",
    "    o[i]=_string.char((v-17)%256)",
    "  end",
    "  return _table.concat(o)",
    "end",
    "local __loader = loadstring or load",
    "if type(__loader)~='function' then error('[HOC NOC] runtime sem loadstring/load') end",
    "local __src=__d(__p)",
    "local __fn,__err=__loader(__src,'@HOC_NOC.release.lua')",
    "if not __fn then error('[HOC NOC] erro ao decodificar build: '..tostring(__err)) end",
    "local __ok,__ret=pcall(__fn)",
    "if not __ok then error('[HOC NOC] erro no bundle: '..tostring(__ret)) end",
    "return __ret",
    "",
  ].join("\\n");
}

function main() {
  ensureInput();
  const src = fs.readFileSync(inputPath, "utf8");
  const encoded = encodeSource(src);
  const wrapped = buildObfuscatedWrapper(encoded);
  fs.writeFileSync(outputPath, banner() + wrapped, "utf8");

  console.log("[OFUSCAMENTO] Ofuscacao concluida:");
  console.log(` - ${outputPath}`);
}

main();
