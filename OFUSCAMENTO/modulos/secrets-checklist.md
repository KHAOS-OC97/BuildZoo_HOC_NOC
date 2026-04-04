# Secrets e Permissoes - OFUSCAMENTO

## 1) Repositorio privado (fonte)

- Repo: BuildZoo_HOC_NOC (privado)
- Workflow: .github/workflows/release-ofuscada.yml

## 2) Repositorio publico (distribuicao)

- Sugestao: BuildZoo_HOC_NOC_DIST
- Branch de distribuicao: main
- Conteudo esperado:
  - HOC_NOC.release.obf.lua
  - Loader.release.lua
  - README.md

## 3) Secrets obrigatorios (repo privado)

- MIRROR_REPO
  - valor: owner/repo publico
  - exemplo: KHAOS-OC97/BuildZoo_HOC_NOC_DIST

- MIRROR_TOKEN
  - valor: token de automacao para push no repo publico

## 4) Secret opcional

- MIRROR_BRANCH
  - valor padrao se ausente: main

## 5) Permissoes minimas do token

Para token classico:
- repo (somente se repo destino for privado)
- public_repo (suficiente quando destino e publico)

Para fine-grained token:
- Repository access: somente repo publico de destino
- Permissions:
  - Contents: Read and write
  - Metadata: Read

## 6) Permissoes do workflow

O workflow ja usa:
- permissions:
  - contents: write

## 7) Fluxo de release

1. Commit no repo privado
2. Criar tag vX.Y.Z
3. Push da tag
4. Action executa build + ofuscacao
5. Release recebe os arquivos finais
6. Mirror atualiza repo publico (quando secrets definidos)

## 8) Verificacao rapida

- Release criada com:
  - HOC_NOC.release.obf.lua
  - Loader.release.lua

- Repo publico atualizado com os mesmos arquivos

- Loader.release.lua apontando para raw correto do repo publico
