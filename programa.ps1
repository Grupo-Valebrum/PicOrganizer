# ProjetoX - Organizador de Imagens por EXIF
# Autor: Nelson Brum
# Colaborador: Jonathas
# Versão: 0.3.1
# Data: 2025-10-01
#
# Observação: este script usa Windows Forms, rode em Windows PowerShell ou PowerShell 7+ (Windows).
# Execução sugerida:
#   powershell -ExecutionPolicy Bypass -File .\programa.ps1

# ================================================================
# CONFIGURAÇÃO INICIAL
# - Força saída UTF8 para evitar problemas de acentuação no console.
# - Carrega assemblies do Windows Forms e Drawing e ativa estilos visuais.
# ================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ================================================================
# FUNÇÕES (comentadas como se eu mesmo as tivesse escrito)
# ================================================================

# ------------------------------------------------
# Select-FolderDialog
# Uso: Abre um diálogo para o usuário selecionar uma pasta
# Racional: reutilizo em origem/destino para consistência visual
# Retorno: caminho selecionado ou $null
# ------------------------------------------------
function Select-FolderDialog {
    param([string]$Description)

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

# ------------------------------------------------
# Get-ExifData
# Uso: extrai metadados EXIF básicos de uma imagem
# Observação: not all images have EXIF; tratamos isso
# Entradas: $FilePath - caminho do arquivo de imagem
# Saída: hashtable com keys CameraFabricante, CameraModelo, DataCaptura, ISO, TempoExposicao, Abertura
# ------------------------------------------------
function Get-ExifData {
    param([string]$FilePath)

    # Abre imagem e lê PropertyItems
    $image = [System.Drawing.Image]::FromFile($FilePath)
    $encoding = [System.Text.Encoding]::ASCII
    $data = @{}

    function Get-PropertyValue([System.Drawing.Imaging.PropertyItem]$prop) {
        try {
            switch ($prop.Type) {
                2 { return ($encoding.GetString($prop.Value)).Trim([char]0) } # string
                default { return $prop.Value }
            }
        } catch { return $null }
    }

    foreach ($prop in $image.PropertyItems) {
        $val = Get-PropertyValue $prop
        switch ($prop.Id) {
            0x010F { $data["CameraFabricante"] = $val }
            0x0110 { $data["CameraModelo"] = $val }
            0x0132 { $data["DataArquivo"] = $val }
            0x9003 { $data["DataCaptura"] = $val }
            0x8827 {
                try { $data["ISO"] = [BitConverter]::ToInt16($prop.Value,0) } catch { $data["ISO"] = $null }
            }
            0x829A {
                if ($prop.Value.Length -ge 8) {
                    $n1 = [BitConverter]::ToInt32($prop.Value,0)
                    $n2 = [BitConverter]::ToInt32($prop.Value,4)
                    if ($n2 -ne 0) { $data["TempoExposicao"] = "$n1/$n2" }
                }
            }
            0x829D {
                if ($prop.Value.Length -ge 8) {
                    $n1 = [BitConverter]::ToInt32($prop.Value,0)
                    $n2 = [BitConverter]::ToInt32($prop.Value,4)
                    if ($n2 -ne 0) { $data["Abertura"] = [Math]::Round($n1 / $n2,2) }
                }
            }
        }
    }

    $image.Dispose()
    return $data
}

# ------------------------------------------------
# SafeSubItem
# Uso: evita inserir $null no ListView (substitui por "N/A")
# ------------------------------------------------
function SafeSubItem {
    param($value)
    if ($null -ne $value -and $value -ne "") { return $value } else { return "N/A" }
}

# ------------------------------------------------
# Get-UniqueFilename
# Uso: gera nome de arquivo único no diretório destino
# Entrada: destDir, baseName (sem extensão), ext (com ponto)
# Retorno: nome (ex: 032024.jpg, 032024_1.jpg)
# ------------------------------------------------
function Get-UniqueFilename {
    param(
        [string]$destDir,
        [string]$baseName,
        [string]$ext
    )
    $candidate = "$baseName$ext"
    $i = 1
    while (Test-Path (Join-Path $destDir $candidate)) {
        $candidate = "{0}_{1}{2}" -f $baseName, $i, $ext
        $i++
    }
    return $candidate
}

# ------------------------------------------------
# Adjust-ListViewColumns
# Uso: calcula larguras das colunas proporcionalmente ao tamanho do ListView
# Racional: mantém layout legível ao redimensionar
# ------------------------------------------------
function Adjust-ListViewColumns {
    param()
    $proportions = @(0.30, 0.18, 0.22, 0.12, 0.12, 0.06)
    $w = $listView.ClientSize.Width
    for ($i = 0; $i -lt $listView.Columns.Count; $i++) {
        $colWidth = [int]([math]::Floor($w * $proportions[$i]))
        if ($colWidth -lt 40) { $colWidth = 40 }
        $listView.Columns[$i].Width = $colWidth
    }
}

# ================================================================
# VARIÁVEIS DE ESTADO (usar $script: para manter escopo entre handlers)
# ================================================================
$script:previewData = @()
$script:sourceFolder = $null
$script:destFolder = $null
$script:isExecuting = $false
$script:cancelRequested = $false

# ================================================================
# INTERFACE GRÁFICA
# - Form principal
# - Painel superior com botões responsivos (FlowLayoutPanel)
# - ListView que ocupa o restante (Dock = Fill)
# ================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProjetoX - Organizador de Imagens"
$form.Size = New-Object System.Drawing.Size(900,520)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

# painel superior (controle dos botões e checkbox)
$topPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$topPanel.Dock = 'Top'
$topPanel.AutoSize = $true
$topPanel.WrapContents = $false
$topPanel.Padding = '8,8,8,8'
$topPanel.FlowDirection = 'LeftToRight'
$form.Controls.Add($topPanel)

# checkbox salvar log
$chkLog = New-Object System.Windows.Forms.CheckBox
$chkLog.Text = "Salvar log das mudanças"
$chkLog.AutoSize = $true
$topPanel.Controls.Add($chkLog)

# botões
$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = "Pré-visualizar"
$btnPreview.AutoSize = $true
$btnPreview.Padding = '6,4,6,4'
$topPanel.Controls.Add($btnPreview)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Executar Mudanças"
$btnRun.AutoSize = $true
$btnRun.Padding = '6,4,6,4'
$topPanel.Controls.Add($btnRun)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.AutoSize = $true
$btnCancel.Padding = '6,4,6,4'
$topPanel.Controls.Add($btnCancel)

# status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Pronto"
$statusLabel.AutoSize = $true
$statusLabel.Margin = '20,6,6,6'
$topPanel.Controls.Add($statusLabel)

# ListView principal
$listView = New-Object System.Windows.Forms.ListView
$listView.Dock = 'Fill'
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.HideSelection = $false
$listView.Font = $form.Font

$listView.Columns.Add("Nome Original",200) | Out-Null
$listView.Columns.Add("Novo Nome",150) | Out-Null
$listView.Columns.Add("Destino",150) | Out-Null
$listView.Columns.Add("Data",100) | Out-Null
$listView.Columns.Add("Câmera",120) | Out-Null
$listView.Columns.Add("ISO",80) | Out-Null

$form.Controls.Add($listView)

# ajustar colunas ao redimensionar e ao mostrar
$form.Add_Resize({ Adjust-ListViewColumns })
$form.Add_Shown({ Adjust-ListViewColumns })

# ================================================================
# EVENTO: Pré-visualizar
# - Prioridade para data no NOME (AAAA-MM-DD)
# - Se não existir, tenta EXIF (DataCaptura ou DataArquivo)
# - Caso contrário, _SEM-DATA_
# - Popula $script:previewData e o ListView
# ================================================================
$btnPreview.Add_Click({
    try {
        $listView.Items.Clear()
        $script:previewData = @()
        $statusLabel.Text = "Selecionando pastas..."

        $script:sourceFolder = Select-FolderDialog -Description "Selecione o diretório com as imagens"
        if (-not $script:sourceFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de origem selecionado."); $statusLabel.Text = "Cancelado"; return }

        $script:destFolder = Select-FolderDialog -Description "Selecione o diretório de destino"
        if (-not $script:destFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de destino selecionado."); $statusLabel.Text = "Cancelado"; return }

        $statusLabel.Text = "Lendo imagens..."
        $images = Get-ChildItem -Path $script:sourceFolder -Include *.jpg,*.jpeg,*.png,*.tiff -File -Recurse -ErrorAction SilentlyContinue

        if (-not $images -or $images.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Nenhuma imagem encontrada no diretório selecionado.")
            $statusLabel.Text = "Nenhuma imagem"
            return
        }

        foreach ($img in $images) {
            # Extrai EXIF (pode ser vazio)
            $exif = Get-ExifData -FilePath $img.FullName

            # Primeiro: verificar se nome do arquivo contém AAAA-MM-DD
            $mesano = "_SEM-DATA_"
            if ($img.Name -match "(\d{4})[-_]?(\d{2})[-_]?(\d{2})") {
                # Aceita 2024-03-15 ou 2024_03_15 ou 20240315 (não exatamente, mas esta regex cobre o formato principal)
                $ano = $matches[1]
                $mes = $matches[2]
                $mesano = "$mes$ano"
            }
            else {
                # Se não encontrou no nome, tenta EXIF (DataCaptura ou DataArquivo)
                $date = if ($exif.ContainsKey("DataCaptura") -and $exif["DataCaptura"]) { $exif["DataCaptura"] } elseif ($exif.ContainsKey("DataArquivo") -and $exif["DataArquivo"]) { $exif["DataArquivo"] } else { $null }

                if ($date -and $date -match "(\d{4}):(\d{2}):(\d{2})") {
                    $ano = $matches[1]
                    $mes = $matches[2]
                    $mesano = "$mes$ano"
                }
            }

            # Monta novo nome e destino (extensão em minúsculo)
            $ext = $img.Extension.ToLower()
            $baseName = $mesano
            $finalDest = Join-Path $script:destFolder $mesano

            # Armazena no preview (usamos $script:previewData para que seja visível em outro handler)
            $script:previewData += [PSCustomObject]@{
                Original = $img.FullName
                BaseName = $baseName
                Ext = $ext
                Destino  = $finalDest
                Data     = SafeSubItem($exif["DataCaptura"])
                Camera   = SafeSubItem($exif["CameraModelo"])
                ISO      = SafeSubItem($exif["ISO"])
            }

            # Exibe no ListView
            $origDisplay = $img.Name
            $newDisplay = "$baseName$ext"
            $destDisplay = $mesano
            $dataDisplay = SafeSubItem($exif["DataCaptura"])
            $cameraDisplay = SafeSubItem($exif["CameraModelo"])
            $isoDisplay = SafeSubItem($exif["ISO"])

            $lvi = New-Object System.Windows.Forms.ListViewItem($origDisplay)
            [void]$lvi.SubItems.Add($newDisplay)
            [void]$lvi.SubItems.Add($destDisplay)
            [void]$lvi.SubItems.Add($dataDisplay)
            [void]$lvi.SubItems.Add($cameraDisplay)
            [void]$lvi.SubItems.Add($isoDisplay)
            [void]$listView.Items.Add($lvi)
        }

        Adjust-ListViewColumns
        $statusLabel.Text = "Pré-visualização concluída. {0} imagens." -f $script:previewData.Count
        [System.Windows.Forms.MessageBox]::Show("Pré-visualização concluída. Verifique a tabela antes de executar.")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erro durante a pré-visualização: `n$($_.Exception.Message)")
        $statusLabel.Text = "Erro"
    }
})

# ================================================================
# EVENTO: Executar Mudanças
# - Usa $script:previewData preenchido pelo Preview
# - Gera nomes únicos e move arquivos
# ================================================================
$btnRun.Add_Click({
    if (-not $script:previewData -or $script:previewData.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nenhuma pré-visualização realizada. Clique em 'Pré-visualizar' primeiro.")
        return
    }

    $script:isExecuting = $true
    $script:cancelRequested = $false
    $btnPreview.Enabled = $false
    $btnRun.Enabled = $false
    $statusLabel.Text = "Executando..."
    $log = @()

    try {
        foreach ($entry in $script:previewData) {
            if ($script:cancelRequested) {
                $log += "Operação cancelada pelo usuário em $(Get-Date -Format o)"
                break
            }

            $orig = $entry.Original
            $destDir = $entry.Destino
            $baseName = $entry.BaseName
            $ext = $entry.Ext

            if (-not (Test-Path $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }

            $uniqueName = Get-UniqueFilename -destDir $destDir -baseName $baseName -ext $ext
            $destFile = Join-Path $destDir $uniqueName

            try {
                Move-Item -Path $orig -Destination $destFile -Force
                $log += "Movido: ${orig} -> ${destFile}"
                $log += "EXIF: Data=${entry.Data} Camera=${entry.Camera} ISO=${entry.ISO}"
                $log += "----"
                $statusLabel.Text = "Movendo: $uniqueName"
                Start-Sleep -Milliseconds 50
            }
            catch {
                $log += "Erro ao mover ${orig}: $($_.Exception.Message)"
            }
        }

        if ($script:cancelRequested) {
            [System.Windows.Forms.MessageBox]::Show("Operação cancelada. Alguns arquivos podem ter sido movidos.")
            $statusLabel.Text = "Cancelado"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Processo concluído.")
            $statusLabel.Text = "Concluído"
        }

        if ($chkLog.Checked -and $log.Count -gt 0) {
            $logFile = Join-Path $script:destFolder ("log_EXIF_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
            $log | Out-File -FilePath $logFile -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Log salvo em:`n$logFile")
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erro durante a execução: `n$($_.Exception.Message)")
        $statusLabel.Text = "Erro"
    }
    finally {
        $script:isExecuting = $false
        $script:cancelRequested = $false
        $btnPreview.Enabled = $true
        $btnRun.Enabled = $true
    }
})

# ================================================================
# EVENTO: Cancelar
# - Se tarefa em execução: sinaliza cancelRequested (cooperação)
# - Se não: limpa preview e mantém app aberto
# ================================================================
$btnCancel.Add_Click({
    if ($script:isExecuting) {
        $script:cancelRequested = $true
        $statusLabel.Text = "Cancelando..."
        [System.Windows.Forms.MessageBox]::Show("Pedido de cancelamento enviado. Aguardando interrupção segura.")
    }
    else {
        $listView.Items.Clear()
        $script:previewData = @()
        $script:sourceFolder = $null
        $script:destFolder = $null
        $statusLabel.Text = "Pré-visualização limpa"
        [System.Windows.Forms.MessageBox]::Show("Pré-visualização limpa. Nenhuma mudança foi realizada.")
    }
})

# ================================================================
# MOSTRAR FORMULÁRIO
# ================================================================
[void]$form.ShowDialog()
