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

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
