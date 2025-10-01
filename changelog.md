# Changelog

Todos os notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), 
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] – 2025-10-01
### Adicionado
- Criação do script inicial `programa.ps1` (antes ProjetoX) com interface gráfica em Windows Forms.
- Função para selecionar diretórios de origem e destino.
- Leitura de metadados EXIF (data de captura, câmera, ISO, exposição, abertura).
- Pré-visualização das imagens em um ListView com colunas: Nome Original, Novo Nome, Destino, Data, Câmera, ISO.
- Botões: Pré-visualizar, Executar Mudanças e Cancelar.
- Geração de logs opcionais das alterações realizadas.
- Renomeação de arquivos baseada no padrão `MMAAAA` para arquivos com EXIF.
- Tratamento de imagens sem dados EXIF, nomeadas como `_SEM-DATA_`.
- Ajuste de arquivos que já possuem data no nome no formato `AAAA-MM-DD`.
- Função `SafeSubItem` para evitar falhas ao exibir valores nulos no ListView.

### Alterado
- Atualização do título da janela para: "Programa - Organizador de Imagens".
- ListView ajustado para tamanho dinâmico (responde ao redimensionamento da janela).
- Corrigidos problemas de caracteres especiais e acentuação na interface.
- Pré-visualização atualizada para exibir apenas a data formatada (MMAAAA) sem repetir o nome do arquivo.

### Corrigido
- Botão Cancelar funcionando corretamente, limpa a lista e reseta variáveis sem fechar o programa.
- ListView com cabeçalhos visíveis e alinhamento correto.
- Mensagens de erro no PowerShell corrigidas (variáveis e concatenação).

### Observações
- Encoding do console ajustado para UTF-8 para evitar caracteres corrompidos.
- Compatibilidade com imagens `.jpg`, `.jpeg`, `.png` e `.tiff`.
- Todas as mudanças implementadas visam escalabilidade e manutenção futura do programa.
