# Changelog

Todos os notable changes to this project serão documentados neste arquivo.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) e 
seguindo [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.1] – 2026-02-20
### Adicionado
- Barra de progresso visual em pré-visualização e execução das mudanças.
- Painel de status com texto e barra de progresso empilhados (abaixo dos botões).
- Estatísticas de pré-visualização: total de imagens e quantidade sem data.
- Progresso em tempo real durante execução: "Executando: N / X imagens...".

### Melhorado
- **Performance**: leitura de EXIF via `FileStream` elimina lock de arquivos.
- **Performance**: `previewData` migrado de array para `List[object]` (escalabilidade em diretórios grandes).
- **UX**: contador de imagens processadas com status dinâmico.
- Nome de arquivo final: formato `dd-MM-yyyy` (ex.: `10-06-2015.jpg`).
- Sleep reduzido para 5ms na execução (menor latência em lotes grandes).

### Corrigido
- Layout responsivo: ListView não sobreponde mais botões ao redimensionar janela.
- Encoding UTF-8 com BOM garantido para acentuação correta em PowerShell 5.1.
- Regex de data restrita a EXIF/arquivo (ignora nomes de arquivo como `671667.jpg`).

### Removido
- Prioridade de data no nome do arquivo (agora exclusivamente EXIF/arquivo).

## [0.3.1] – 2025-10-01
### Alterado
- Renomeação do script de `ProjetoX` para `programa.ps1`.
- Ajuste no título do programa: "Programa - Organizador de Imagens".
- ListView ajustado para tamanho dinâmico conforme redimensionamento da janela.
- Correção de caracteres especiais e acentuação na interface.
- Ajuste no botão Cancelar: agora limpa preview sem fechar o programa.
- Pré-visualização exibindo apenas data MMAAAA sem repetir o nome do arquivo.

## [0.3.0] – 2025-09-30
### Adicionado
- Suporte a arquivos que possuem data no nome no formato `AAAA-MM-DD` para renomeação automática.
- ListView exibindo colunas: Nome Original, Novo Nome, Destino, Data, Câmera, ISO.
- Função `SafeSubItem` para evitar valores nulos quebrando o programa.
- Botões de execução: Pré-visualizar, Executar Mudanças, Cancelar.
- Logs opcionais detalhados das operações.

## [0.2.0] – 2025-09-25
### Corrigido
- Pré-visualização agora funciona corretamente, carregando os dados de EXIF.
- Tratamento de imagens sem dados EXIF, renomeadas para `_SEM-DATA_`.
- Correção de problemas de codificação no PowerShell.

## [0.1.0] – 2025-09-20
### Adicionado
- Primeira versão funcional do ProjetoX com interface gráfica.
- Seleção de diretórios de origem e destino.
- Leitura de metadados EXIF básicos: data, câmera e ISO.
- Movimentação de arquivos para pastas `MMAAAA`.

## [0.0.2] – 2025-09-18
### Adicionado
- Pré-visualização das alterações antes de executar.
- Log detalhado opcional das operações.

## [0.0.1] – 2025-09-15
### Inicial
- Criação inicial do script com função de renomear imagens por EXIF.
- Suporte a arquivos `.jpg` e `.jpeg`.

