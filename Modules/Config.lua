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
    AUTO_BUY_SILENT_SWEEP = 5,
    AUTO_BUY_FRUIT_COOLDOWN = 20,
    AUTO_BUY_REQUEST_SPACING = 0.08,
    AUTO_BUY_REMOTE_SCAN_INTERVAL = 30,
    AUTO_BUY_GUI_SCAN_INTERVAL = 8.0,
    AUTO_BUY_GUI_ONLY = false,
    AUTO_BUY_ALLOW_GUI_FALLBACK = true,
    AUTO_BUY_STRICT_COIN_ONLY = true,
    AUTO_BUY_FORCE_GUI_FALLBACK_AFTER_SILENT = false,

    -- BigPetFeed (modo silencioso por remotes)
    BIG_PET_FEED_LOOP_INTERVAL = 1.0,
    BIG_PET_FEED_SWEEP = 8,
    BIG_PET_FEED_PET_COOLDOWN = 6,
    BIG_PET_FEED_REQUEST_SPACING = 0.08,
    BIG_PET_FEED_REMOTE_SCAN_INTERVAL = 30,
    BIG_PET_FEED_ALLOW_TOOL_ACTIVATE_FALLBACK = true,
    BIG_PET_FEED_ALLOW_PROMPT_FALLBACK = true,
    BIG_PET_FEED_FORCE_FALLBACK_AFTER_SILENT = true,
    BIG_PET_FEED_INTERACT_DISTANCE = 4,
    BIG_PET_FEED_PROMPT_RADIUS = 20,
    BIG_PET_FEED_PROMPT_RETRY = 3,
    BIG_PET_FEED_KEYWORDS = {
        "pet", "big", "feed", "food", "eat", "hunger", "consume", "fruit", "use",
    },
    BIG_PET_IDS = {
        "afe26d3344da424bb3f5efa6e56df287",
        "0364afa6d90d412b9d5089a1b81d5860",
    },

    -- Usuários aliados para teleporte
    TARGET_USERS = {"KChaos97", "CKhaos79"},

    -- Palavras-chave para detectar a loja de frutas no PlayerGui
    FRUIT_SHOP_KEYWORDS = {"fruit", "food", "feed", "seed", "product", "itemshop"},

    -- Lista completa de frutas (alinhada aos textos exibidos na UI)
    FRUITS = {
        {name = "Strawberry",          price = "5,000"  },
        {name = "Blueberry",           price = "20,000" },
        {name = "Watermelon",          price = "80,000" },
        {name = "Apple",               price = "400,000"},
        {name = "Orange",              price = "1.2M"   },
        {name = "Corn",                price = "3.5M"   },
        {name = "Banana",              price = "12M"    },
        {name = "Grape",               price = "50M"    },
        {name = "Pear",                price = "200M"   },
        {name = "Pineapple",           price = "600M"   },
        {name = "Dragon Fruit",        price = "1.5B"   },
        {name = "Gold Mango",          price = "2B"     },
        {name = "Bloodstone Cycad",    price = "8B"     },
        {name = "Colossal Pinecone",   price = "40B"    },
        {name = "Volt Ginkgo",         price = "80B"    },
        {name = "Deepsea Pearl Fruit", price = "40B"    },
        {name = "Candy Corn",          price = "50B"    },
        {name = "Durian",              price = "80B"    },
        {name = "Pumpkin",             price = "80B"    },
        {name = "Franken Kiwi",        price = "80B"    },
        {name = "Acorn",               price = "80B"    },
        {name = "Cranberry",           price = "80B"    },
        {name = "Gingerbread",         price = "80B"    },
        {name = "Candy Cane",          price = "80B"    },
        {name = "Cherry",              price = "80B"    },
    },

    -- Normalizacao de nomes reais encontrados em varredura runtime.
    -- "path" e "resId" sao usados para ampliar tentativas de argumentos em remotes.
    FRUIT_CANONICAL = {
        ["Strawberry"] = {
            path = "PetFood/Strawberry",
            resId = 153,
            aliases = {"Strawberry", "PetFood/Strawberry"},
        },
        ["Blueberry"] = {
            path = "PetFood/Blueberry",
            resId = 146,
            aliases = {"Blueberry", "PetFood/Blueberry"},
        },
        ["Watermelon"] = {
            path = "PetFood/Watermelon",
            resId = 148,
            aliases = {"Watermelon", "PetFood/Watermelon"},
        },
        ["Apple"] = {
            path = "PetFood/Apple",
            resId = 152,
            aliases = {"Apple", "apple", "PetFood/Apple"},
        },
        ["Orange"] = {
            path = "PetFood/Orange",
            resId = 149,
            aliases = {"Orange", "orange", "PetFood/Orange"},
        },
        ["Pineapple"] = {
            path = "PetFood/Pineapple",
            resId = 150,
            aliases = {"Pineapple", "PineApple", "pineapple", "PetFood/Pineapple"},
        },
        ["Corn"] = {
            path = "PetFood/Corn",
            aliases = {"Corn", "PetFood/Corn"},
        },
        ["Candy Corn"] = {
            path = "PetFood/CandyCorn",
            aliases = {"Candy Corn", "CandyCorn", "PetFood/CandyCorn"},
        },
        ["Acorn"] = {
            path = "PetFood/Acorn",
            aliases = {"Acorn", "PetFood/Acorn"},
        },
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
