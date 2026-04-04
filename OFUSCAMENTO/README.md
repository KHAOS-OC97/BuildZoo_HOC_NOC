# OFUSCAMENTO

Este diretorio concentra toda a esteira de distribuicao ofuscada.

## Estrutura

- modulos/settings.json: configuracao principal da esteira
- modulos/module-order.json: ordem de empacotamento dos modulos Lua
- scripts/build.js: gera bundle standalone e loader publico
- scripts/obfuscate.js: ofusca/minifica o bundle
- scripts/mirror.js: espelha artefatos para repositorio publico (opcional)
- dist/: artefatos gerados localmente

## Uso local

1) Instalar dependencias

npm --prefix OFUSCAMENTO install

2) Gerar release local

npm --prefix OFUSCAMENTO run release:prepare

3) Artefatos finais

- OFUSCAMENTO/dist/HOC_NOC.release.obf.lua
- OFUSCAMENTO/dist/Loader.release.lua

## Como configurar o espelhamento automatico

No repositorio privado, configure os secrets:

- MIRROR_REPO: owner/repo publico de distribuicao
- MIRROR_TOKEN: token com permissao de push no repo publico
- MIRROR_BRANCH: branch de destino (opcional, default main)

Quando os secrets estiverem definidos, o workflow publica automaticamente no repo publico.

## Checklist rapido de ativacao

1) Crie (ou confirme) o repo publico de distribuicao.

2) Confirme o destino no arquivo modulos/settings.json:

- distOwner
- distRepo
- distBranch

3) No repo privado, adicione os secrets:

- MIRROR_REPO (exemplo: KHAOS-OC97/BuildZoo_HOC_NOC_DIST)
- MIRROR_TOKEN (token com acesso de escrita ao repo publico)
- MIRROR_BRANCH (opcional, padrao: main)

4) Gere uma tag para release automatica:

git tag v1.0.4
git push origin v1.0.4

5) O workflow release-ofuscada vai:

- gerar OFUSCAMENTO/dist/HOC_NOC.release.lua
- gerar OFUSCAMENTO/dist/HOC_NOC.release.obf.lua
- gerar OFUSCAMENTO/dist/Loader.release.lua
- publicar assets na Release do GitHub
- espelhar para o repo publico (se secrets estiverem definidos)

Detalhes de permissoes e hardening: OFUSCAMENTO/modulos/secrets-checklist.md

## Loader publico

O arquivo Loader.release.lua aponta para:

https://raw.githubusercontent.com/KHAOS-OC97/BuildZoo_HOC_NOC_DIST/main/HOC_NOC.release.obf.lua

Esses valores sao controlados em modulos/settings.json.

