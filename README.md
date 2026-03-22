# 🐢 BuildZoo_HOC_NOC

> ### ⚡ Modular, direto e pronto para uso no Build Zoo
>
> Interface própria, módulos separados, loader remoto e organização pensada para manutenção rápida.

---

## 🌟 Visão geral

O **BuildZoo_HOC_NOC** é um projeto modular em **Lua** para Roblox, estruturado para manter o código limpo, separado por responsabilidade e fácil de evoluir.

O foco aqui não é só “funcionar”.
A ideia é ter uma base que fique **visual, organizada, estável e simples de atualizar**.

### ✨ Destaques

- 🧩 Arquitetura modular
- 🎛️ GUI própria com controles rápidos
- 🚀 Loader remoto via GitHub
- 🛒 AutoBuy com seleção de frutas
- 👀 ESP com efeito RGB
- 🦘 Jump infinito
- 🏃 Controle de WalkSpeed
- 🔁 Server Hop
- 🤝 Teleporte para aliado
- 🛡️ Anti-AFK reforçado

---

## 🧠 Estrutura do projeto

```text
BuildZoo_HOC_NOC/
├── Loader.lua
├── Main.lua
├── README.md
└── Modules/
    ├── AntiAFK.lua
    ├── AutoBuy.lua
    ├── Config.lua
    ├── ESP.lua
    ├── Movement.lua
    ├── ServerHop.lua
    ├── Services.lua
    ├── State.lua
    ├── Teleport.lua
    └── GUI/
        ├── Buttons.lua
        ├── Core.lua
        ├── FruitMenu.lua
        └── Toggles.lua
```

---

## 🎯 Recursos principais

### 🛡️ Anti-AFK

Sistema reforçado para reduzir falhas por inatividade, usando abordagem em camadas:

- evento de idle
- pulsos periódicos
- VirtualUser
- VirtualInputManager quando disponível
- pulso de movimento no Humanoid

### 🎛️ GUI integrada

Interface com:

- toggles animados
- botões de ação
- borda RGB
- atalho de teclado para mostrar/ocultar

### 🛒 AutoBuy de frutas

Compra automática baseada nas frutas selecionadas no menu.

### 🏃 Movimento

- ciclo de velocidade
- aplicação automática ao respawn
- jump infinito

### 🌐 Mobilidade e sessão

- Server Hop para outro servidor público
- TP para jogadores aliados configurados

---

## 🧱 Organização dos módulos

| Módulo | Função |
|---|---|
| `Loader.lua` | Carregador remoto via GitHub |
| `Main.lua` | Ponto central de inicialização |
| `Modules/Config.lua` | Configurações fixas e listas |
| `Modules/State.lua` | Estado global e referências da GUI |
| `Modules/Services.lua` | Serviços centralizados do Roblox |
| `Modules/AntiAFK.lua` | Anti-AFK e pulsos de atividade |
| `Modules/Movement.lua` | WalkSpeed e jump infinito |
| `Modules/AutoBuy.lua` | Compra automática |
| `Modules/ServerHop.lua` | Troca de servidor |
| `Modules/Teleport.lua` | Teleporte para aliado |
| `Modules/GUI/*` | Construção da interface |

---

## 🚀 Como usar

### Opção 1: Loader remoto

Use o `Loader.lua` para baixar tudo direto do GitHub.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/KHAOS-OC97/BuildZoo_HOC_NOC/main/Loader.lua", true))()
```

### Opção 2: Execução local

Se estiver usando estrutura local com `readfile()`:

```lua
loadstring(readfile("HOC_NOC_Zoo/Main.lua"))()
```

---

## 🔁 Persistência após teleporte

Se o executor suportar `queue_on_teleport`, você pode preparar o recarregamento automático:

### Local

```lua
queue_on_teleport([[loadstring(readfile("HOC_NOC_Zoo/Main.lua"))()]])
```

### Remoto

```lua
queue_on_teleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/KHAOS-OC97/BuildZoo_HOC_NOC/main/Loader.lua", true))()]])
```

---

## 🎮 Controles e interface

### Toggles disponíveis

- MAGNET STEALTH
- AUTO-BUILD REMOTE
- AUTO-GIFTS (GUI)
- JUMP INFINITY
- MAX RANGE ESP (RGB)
- ANTI-AFK MARINES

### Botões disponíveis

- WALKSPEED
- OPEN FRUIT SHOP
- SERVER HOP (EXTRAÇÃO)
- EXTRAÇÃO TP

### Atalho

- `LeftControl`: mostra ou oculta a interface

---

## 🍍 Lista de frutas suportadas

O projeto já possui uma lista interna de frutas para seleção no menu, incluindo exemplos como:

- Orange
- Corn
- Banana
- Grape
- Pear
- Pineapple
- DragonFruit
- GoldMango
- BloodstoneCycad
- ColossalPinecone
- DeepseaPearlFruit
- VoltGinkgo
- CandyCorn
- Durian
- Pumpkin
- FrankenKiwi
- Acorn
- Cranberry
- Gingerbread
- Candycane
- Cherry

---

## 🎨 Filosofia do projeto

Este repositório foi montado com algumas prioridades claras:

- código separado por responsabilidade
- manutenção simples
- leitura rápida
- atualização fácil
- aparência mais marcante do que um script solto e desorganizado

---

## 📌 Observações

- O projeto usa carregamento modular.
- A ordem de inicialização importa.
- Alguns recursos dependem do suporte do executor.
- A interface pode ser recriada automaticamente se for removida.

---

## 🔥 Resumo rápido

Se alguém abrir este repositório, a ideia é bater o olho e entender:

- o projeto tem identidade
- o código está organizado
- existe separação por módulos
- a GUI já está pronta
- o loader remoto facilita atualização

---

## 🦁 BuildZoo_HOC_NOC

> Bonito por fora, modular por dentro, fácil de manter.
