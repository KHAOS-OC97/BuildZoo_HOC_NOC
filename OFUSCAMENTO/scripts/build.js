const fs = require("fs");
const path = require("path");

const ofRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(ofRoot, "..");
const distDir = path.join(ofRoot, "dist");

const settings = JSON.parse(
  fs.readFileSync(path.join(ofRoot, "modulos", "settings.json"), "utf8")
);
const moduleOrder = JSON.parse(
  fs.readFileSync(path.join(ofRoot, "modulos", "module-order.json"), "utf8")
);

function toLuaLongString(content) {
  let eq = "";
  while (content.includes(`]${eq}]`)) {
    eq += "=";
  }
  return `[${eq}[${content}]${eq}]`;
}

function nowIso() {
  return new Date().toISOString();
}

function ensureDist() {
  fs.mkdirSync(distDir, { recursive: true });
}

function getVersionLabel() {
  return (
    process.env.RELEASE_VERSION ||
    process.env.GITHUB_REF_NAME ||
    "dev-local"
  );
}

function buildModulesTable() {
  return moduleOrder
    .map((relPath) => {
      const absPath = path.join(repoRoot, relPath);
      if (!fs.existsSync(absPath)) {
        throw new Error(`Modulo nao encontrado: ${relPath}`);
      }
      const src = fs.readFileSync(absPath, "utf8");
      return `    [${JSON.stringify(relPath)}] = ${toLuaLongString(src)}`;
    })
    .join(",\n");
}

function buildReleaseScript() {
  const version = getVersionLabel();
  const generatedAt = nowIso();
  const users = (settings.allowedUsers || [])
    .map((u) => String(u || "").trim().toLowerCase())
    .filter(Boolean)
    .map((u) => `[${JSON.stringify(u)}] = true`)
    .join(", ");
  const userIds = (settings.allowedUserIds || [])
    .map((id) => Number(id))
    .filter((id) => Number.isInteger(id) && id > 0)
    .map((id) => `[${id}] = true`)
    .join(", ");

  const modulesTable = buildModulesTable();

  return `--[[
    AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
    Source repo: private
    Version: ${version}
    GeneratedAt: ${generatedAt}
]]

local __HOC_MODULES = {
${modulesTable}
}

local function __hoc_loadModule(relPath)
    local src = __HOC_MODULES[relPath]
    if not src then
        error("[HOC NOC] Modulo nao encontrado no bundle: " .. tostring(relPath), 2)
    end

    local fn, compileErr = loadstring(src, "@" .. relPath)
    if not fn then
        error("[HOC NOC] Erro de compilacao em '" .. relPath .. "': " .. tostring(compileErr), 2)
    end

    local execOk, result = pcall(fn)
    if not execOk then
        error("[HOC NOC] Erro de execucao em '" .. relPath .. "': " .. tostring(result), 2)
    end

    return result or {}
end

local function __hoc_safeInvoke(label, fn)
    if type(fn) ~= "function" then
        warn("[HOC NOC] Etapa ausente: " .. tostring(label))
        return false
    end

    local ok, err = pcall(fn)
    if not ok then
        warn("[HOC NOC] Falha em " .. tostring(label) .. ": " .. tostring(err))
        return false
    end

    return true
end

do
    local ALLOWED_USERS = { ${users} }
  local ALLOWED_USER_IDS = { ${userIds} }

  local function normalizeName(v)
    return string.lower(tostring(v or ""))
  end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local name = player and player.Name or ""
  local userId = player and player.UserId or 0
  local normalizedName = normalizeName(name)

  local hasNameRules = next(ALLOWED_USERS) ~= nil
  local hasIdRules = next(ALLOWED_USER_IDS) ~= nil
  local nameAllowed = (not hasNameRules) or (ALLOWED_USERS[normalizedName] == true)
  local idAllowed = (not hasIdRules) or (ALLOWED_USER_IDS[userId] == true)

  if not (nameAllowed and idAllowed) then
    warn("[HOC NOC] Access denied")
        return
    end

  _G.__HOC_AUTHORIZED = true
end

local ctx = {}
ctx.Config = __hoc_loadModule("Modules/Config.lua")
ctx.State = __hoc_loadModule("Modules/State.lua")
ctx.Services = __hoc_loadModule("Modules/Services.lua")

do
  if _G.__HOC_AUTHORIZED == true then
        ctx.AutoLike = __hoc_loadModule("Modules/AutoLike.lua")
    end
end

ctx.AntiAFK = __hoc_loadModule("Modules/AntiAFK.lua")
ctx.ESP = __hoc_loadModule("Modules/ESP.lua")
ctx.Movement = __hoc_loadModule("Modules/Movement.lua")
ctx.Fly = __hoc_loadModule("Modules/Fly.lua")
ctx.AutoFish = __hoc_loadModule("Modules/AutoFish.lua")
ctx.AutoBuy = __hoc_loadModule("Modules/AutoBuy.lua")
ctx.BigPetFeed = __hoc_loadModule("Modules/BigPetFeed.lua")
ctx.ServerHop = __hoc_loadModule("Modules/ServerHop.lua")
ctx.Teleport = __hoc_loadModule("Modules/Teleport.lua")
ctx.Emotes = __hoc_loadModule("Modules/Emotes.lua")
ctx.CollectCoin = __hoc_loadModule("Modules/CollectCoin.lua")

ctx.GUI = {
    Toggles = __hoc_loadModule("Modules/GUI/Toggles.lua"),
    Buttons = __hoc_loadModule("Modules/GUI/Buttons.lua"),
    FruitMenu = __hoc_loadModule("Modules/GUI/FruitMenu.lua"),
    Core = __hoc_loadModule("Modules/GUI/Core.lua"),
}

__hoc_safeInvoke("AntiAFK.Init", function() ctx.AntiAFK.Init(ctx) end)
__hoc_safeInvoke("ESP.Init", function() ctx.ESP.Init(ctx) end)
__hoc_safeInvoke("Movement.Init", function() ctx.Movement.Init(ctx) end)
__hoc_safeInvoke("Fly.Init", function() ctx.Fly.Init(ctx) end)
__hoc_safeInvoke("AutoFish.Init", function() ctx.AutoFish.Init(ctx) end)
__hoc_safeInvoke("AutoBuy.Init", function() ctx.AutoBuy.Init(ctx) end)
__hoc_safeInvoke("BigPetFeed.Init", function() ctx.BigPetFeed.Init(ctx) end)
__hoc_safeInvoke("ServerHop.Init", function() ctx.ServerHop.Init(ctx) end)
__hoc_safeInvoke("Teleport.Init", function() ctx.Teleport.Init(ctx) end)

if ctx.AutoLike and ctx.AutoLike.Init then
    __hoc_safeInvoke("AutoLike.Init", function() ctx.AutoLike.Init(ctx) end)
end
__hoc_safeInvoke("Emotes.Init", function() ctx.Emotes.Init(ctx) end)

__hoc_safeInvoke("GUI.Core.Build", function() ctx.GUI.Core.Build(ctx) end)

task.spawn(function()
    while _G_Running do
        local stored = ctx.State.Stored
        if not (stored.ScreenGui and stored.ScreenGui.Parent) then
            __hoc_safeInvoke("GUI.Core.Build (monitor)", function() ctx.GUI.Core.Build(ctx) end)
        end
        __hoc_safeInvoke("AntiAFK.Ping", function() ctx.AntiAFK.Ping() end)
        task.wait(ctx.Config.ANTI_AFK_INTERVAL)
    end
end)

local LocalPlayer = ctx.Services.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(char)
    __hoc_safeInvoke("Movement.ApplyToCharacter(CharacterAdded)", function()
        ctx.Movement.ApplyToCharacter(char)
    end)
end)

if LocalPlayer.Character then
    __hoc_safeInvoke("Movement.ApplyToCharacter(Current)", function()
        ctx.Movement.ApplyToCharacter(LocalPlayer.Character)
    end)
end
`;
}

function buildReleaseLoader() {
  const owner = process.env.DIST_OWNER || settings.distOwner;
  const repo = process.env.DIST_REPO || settings.distRepo;
  const branch = process.env.DIST_BRANCH || settings.distBranch || "main";
  const distScriptFile = settings.distScriptFile;
  const distUrl = `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${distScriptFile}`;

  return `--[[
    Public loader for obfuscated distribution.
    Auto-generated by OFUSCAMENTO/scripts/build.js
]]
local src = game:HttpGet(${JSON.stringify(distUrl)}, true)
if not src or src == "" then
    error("[HOC NOC] Falha ao baixar script ofuscado.")
end
local fn, err = loadstring(src, "@${distScriptFile}")
if not fn then
    error("[HOC NOC] Erro ao compilar script ofuscado: " .. tostring(err))
end
return fn()
`;
}

function main() {
  ensureDist();

  const releaseScriptPath = path.join(distDir, "HOC_NOC.release.lua");
  const releaseLoaderPath = path.join(distDir, settings.distLoaderFile || "Loader.release.lua");

  fs.writeFileSync(releaseScriptPath, buildReleaseScript(), "utf8");
  fs.writeFileSync(releaseLoaderPath, buildReleaseLoader(), "utf8");

  console.log("[OFUSCAMENTO] Build concluida:");
  console.log(` - ${releaseScriptPath}`);
  console.log(` - ${releaseLoaderPath}`);
}

main();
