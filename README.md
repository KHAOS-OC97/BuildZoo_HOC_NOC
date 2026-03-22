# BuildZoo_HOC_NOC
TOP Secret
HOC_NOC_Zoo/
├── Main.lua                 ← Ponto de entrada (loader + orquestrador)
└── Modules/
    ├── Config.lua           ← Dados estáticos (frutas, cores, constantes)
    ├── State.lua            ← Estado global (_G_* flags + referências da GUI)
    ├── Services.lua         ← Serviços do Roblox centralizados
    ├── AntiAFK.lua          ← Idled + pings periódicos
    ├── ESP.lua              ← BillboardGui RGB por jogador
    ├── Movement.lua         ← WalkSpeed + Pulo Infinito
    ├── AutoBuy.lua          ← Loop de compra automática
    ├── ServerHop.lua        ← Troca de servidor
    ├── Teleport.lua         ← TP para aliado
    └── GUI/
        ├── Core.lua         ← Frame principal, título, fechar, CTRL, RGB loop
        ├── Toggles.lua      ← 6 switches animados
        ├── Buttons.lua      ← WalkSpeed / Loja / ServerHop / TP com RGB stroke
        └── FruitMenu.lua    ← Dropdown, Select All/Clear, AutoBuy, Amount