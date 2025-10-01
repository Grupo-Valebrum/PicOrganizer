# ![ProjetoX](https://img.shields.io/badge/ProjetoX-EXIF%20Organizer-blue) ProjetoX - Organizador de Imagens

**ProjetoX** é um **organizador gráfico de imagens** desenvolvido em PowerShell. Ele permite **renomear, organizar, mover entre diretórios e gerar logs de toda essa movimentação** com base nos metadados EXIF, de forma rápida e segura.

---

## ✨ Funcionalidades

- ✅ Extrai dados EXIF legíveis:
  - Data de captura
  - Modelo da câmera
  - ISO
  - Tempo de exposição
  - Abertura
- ✅ Renomeia imagens para o padrão `MMAAAA` ou `_SEM-DATA_` se não houver EXIF.
- ✅ Agrupa imagens em pastas `MMAAAA` no diretório de destino.
- ✅ Pré-visualização em tabela antes de executar as alterações.
- ✅ Log detalhado das operações (opcional).
- ✅ Botões para **executar** ou **cancelar** a operação.

---

## 📌 Pré-visualização do Programa

![Exemplo de Pré-visualização](https://via.placeholder.com/800x400?text=Pré-visualização+ProjetoX)

> O ListView exibe os arquivos originais, o novo nome, destino e dados EXIF extraídos.

---

## 🖥️ Requisitos

- Windows PowerShell 5.x ou PowerShell 7+  
- Sistema operacional: Windows (usa `System.Windows.Forms` e `System.Drawing`)  
- Permissão para executar scripts:

---
## 🗂 Estrutura do Projeto
ProjetoX/
- ProjetoX.ps1        # Script principal do organizador de imagens EXIF
- LICENSE             # Arquivo da Licença MIT
- README.md           # Documentação e instruções do projeto
- CHANGELOG.md        # Histórico de versões e alterações

---
## Descrição dos arquivos:

|Arquivo      | Função                                                                  |
|-------------|-------------------------------------------------------------------------|
|ProjetoX.ps1 | Script principal que organiza, renomeia e gera logs das imagens.        |
|LICENSE      | Licença MIT para o projeto.                                             |
|README.md    | Documentação completa com instruções de uso, funcionalidades e setup.   |
|CHANGELOG.md | Histórico de alterações e melhorias do projeto.                         |

---
## 🚀 Instalação e Uso
1. Clonar o repositório

Abra o terminal no VSCode ou PowerShell e execute:

```bash
git clone https://github.com/Grupo-Valebrum/ProjetoX.git
cd ProjetoX
```
2. Configurar permissões para execução de scripts

No PowerShell, rode:

```bash
powershell Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Isso permite que o script seja executado localmente sem restrições.

3. Executar o ProjetoX

No terminal, execute o script principal:

```bash
powershell -ExecutionPolicy Bypass -File .\ProjetoX.ps1
```

4. Passos dentro do programa
    1. Selecionar a pasta de origem com as imagens que deseja organizar.
    2. Selecionar a pasta de destino onde as imagens renomeadas e organizadas serão salvas.
    3. Pré-visualizar as alterações no ListView do programa.
    4. Escolher entre Executar Mudanças ou Cancelar.
    5. Se desejar, marcar a opção para salvar log detalhado das operações.
    6. Imagens sem dados EXIF serão renomeadas para _SEM-DATA_ e incluídas em pastas correspondentes.
