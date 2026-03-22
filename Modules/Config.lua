--[[
    Config.lua — Dados estáticos e constantes imutáveis.
    Nenhuma lógica de execução aqui; apenas valores de configuração.
]]

return {
    VERSION  = "1.0.3",
    GUI_NAME = "HOC_NOC_ELITE_V6_4",
    TITLE    = "🐢 HOC NOC Zoo v1.0.3 🦁",

    -- Ciclo de velocidades (WalkSpeed)
    WALK_SPEED_CYCLE = {16, 50, 100},

    -- Intervalo (segundos) entre pings periódicos de Anti-AFK
    ANTI_AFK_INTERVAL = 60,

    -- AutoBuy (modo silencioso por remotes)
    AUTO_BUY_LOOP_INTERVAL = 1.0,
    AUTO_BUY_SILENT_SWEEP = 15,
    AUTO_BUY_FRUIT_COOLDOWN = 20,
    AUTO_BUY_REQUEST_SPACING = 0.08,
    AUTO_BUY_REMOTE_SCAN_INTERVAL = 30,
    AUTO_BUY_GUI_SCAN_INTERVAL = 8.0,
    AUTO_BUY_ALLOW_GUI_FALLBACK = false,

    -- Usuários aliados para teleporte
    TARGET_USERS = {"KChaos97", "CKhaos79"},

    -- Palavras-chave para detectar a loja de frutas no PlayerGui
    FRUIT_SHOP_KEYWORDS = {"fruit", "food", "feed", "seed", "product", "itemshop"},

    -- Lista completa de frutas
    FRUITS = {
        {name = "Orange",            price = "1.2M" },
        {name = "Corn",              price = "3.5M" },
        {name = "Banana",            price = "12M"  },
        {name = "Grape",             price = "50M"  },
        {name = "Pear",              price = "200M" },
        {name = "Pineapple",         price = "600M" },
        {name = "DragonFruit",       price = "1.5B" },
        {name = "GoldMango",         price = "2B"   },
        {name = "BloodstoneCycad",   price = "8B"   },
        {name = "ColossalPinecone",  price = "40B"  },
        {name = "DeepseaPearlFruit", price = "40B"  },
        {name = "VoltGinkgo",        price = "80B"  },
        {name = "CandyCorn",         price = "500B" },
        {name = "Durian",            price = "80B"  },
        {name = "Pumpkin",           price = "80B"  },
        {name = "FrankenKiwi",       price = "800B" },
        {name = "Acorn",             price = "80B"  },
        {name = "Cranberry",         price = "80B"  },
        {name = "Gingerbread",       price = "80B"  },
        {name = "Candycane",         price = "80B"  },
        {name = "Cherry",            price = "80B"  },
    },

    -- Paleta de cores centralizada
    Colors = {
        Dark      = Color3.fromRGB(5,   5,   5  ),
        DarkMid   = Color3.fromRGB(30,  30,  30 ),
        DarkItem  = Color3.fromRGB(44,  44,  44 ),
        Green     = Color3.fromRGB(20,  120, 60 ),
        DarkGreen = Color3.fromRGB(6,   100, 50 ),
        Red       = Color3.fromRGB(150, 0,   0  ),
        DarkRed   = Color3.fromRGB(130, 40,  40 ),
        Gray      = Color3.fromRGB(80,  80,  80 ),
        White     = Color3.new(1, 1, 1),
        LightGray = Color3.fromRGB(200, 200, 200),
    },
}
