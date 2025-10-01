# Changelog

Todos os notable changes to this project serão documentados neste arquivo.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) e 
seguindo [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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

