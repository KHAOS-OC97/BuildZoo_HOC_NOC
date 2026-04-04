const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const ofRoot = path.resolve(__dirname, "..");
const distDir = path.join(ofRoot, "dist");

function run(cmd, cwd) {
  execSync(cmd, {
    cwd,
    stdio: "inherit",
    env: process.env,
  });
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Variavel obrigatoria ausente: ${name}`);
  }
  return value;
}

function ensureDistArtifacts() {
  const required = ["HOC_NOC.release.obf.lua", "Loader.release.lua"];
  for (const file of required) {
    const full = path.join(distDir, file);
    if (!fs.existsSync(full)) {
      throw new Error(`Artefato nao encontrado: ${full}`);
    }
  }
}

function main() {
  ensureDistArtifacts();

  const mirrorRepo = requireEnv("MIRROR_REPO");
  const token = requireEnv("MIRROR_TOKEN");
  const branch = process.env.MIRROR_BRANCH || "main";
  const gitUserName = process.env.MIRROR_GIT_USER || "github-actions[bot]";
  const gitUserEmail = process.env.MIRROR_GIT_EMAIL || "41898282+github-actions[bot]@users.noreply.github.com";

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hoc-noc-mirror-"));
  const remote = `https://x-access-token:${token}@github.com/${mirrorRepo}.git`;

  run(`git clone --depth 1 --branch ${branch} ${remote} mirror`, tempDir);

  const mirrorPath = path.join(tempDir, "mirror");
  const filesToCopy = ["HOC_NOC.release.obf.lua", "Loader.release.lua"];
  for (const file of filesToCopy) {
    fs.copyFileSync(path.join(distDir, file), path.join(mirrorPath, file));
  }

  const readme = [
    "# BuildZoo HOC NOC Dist",
    "",
    "Repositorio publico de distribuicao automatica.",
    "Nao contem codigo fonte modular.",
    "",
    "Arquivos principais:",
    "- Loader.release.lua",
    "- HOC_NOC.release.obf.lua",
    "",
    "Gerado por pipeline OFUSCAMENTO.",
  ].join("\n");
  fs.writeFileSync(path.join(mirrorPath, "README.md"), readme + "\n", "utf8");

  run(`git config user.name ${JSON.stringify(gitUserName)}`, mirrorPath);
  run(`git config user.email ${JSON.stringify(gitUserEmail)}`, mirrorPath);
  run("git add -A", mirrorPath);

  try {
    run(
      `git commit -m ${JSON.stringify(
        `dist: update obfuscated release ${process.env.GITHUB_REF_NAME || "manual"}`
      )}`,
      mirrorPath
    );
  } catch (_err) {
    console.log("[OFUSCAMENTO] Mirror sem alteracoes para commit.");
    return;
  }

  run(`git push origin ${branch}`, mirrorPath);
  console.log(`[OFUSCAMENTO] Mirror concluido em ${mirrorRepo}@${branch}`);
}

main();
