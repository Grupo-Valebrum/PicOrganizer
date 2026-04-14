# PicOrganizer - Organizador de Imagens por EXIF
# Idealizador: Nelson Brum
# Desenvolvedor: Jonathas Cunha
# Versão: 0.3.2
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
[System.Threading.Thread]::CurrentThread.CurrentCulture = 'pt-BR'
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'pt-BR'
[System.Windows.Forms.Application]::EnableVisualStyles()

# ================================================================
# FUNÇÕES
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
# Observação: nem todas imagens tem metadados EXIF; tratamos isso
# Entradas: $FilePath - caminho do arquivo de imagem
# Saída: hashtable com keys CameraFabricante, CameraModelo, DataCaptura, ISO, TempoExposicao, Abertura
# ------------------------------------------------
function Get-ExifData {
    param([string]$FilePath)

    $data = @{}
    $encoding = [System.Text.Encoding]::ASCII

    try {
        # Abre o arquivo em modo leitura, compartilhando com outros processos
        $fs = [System.IO.File]::Open(
            $FilePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )

        try {
            # Carrega a imagem a partir do stream (evita lock prolongado)
            $image = [System.Drawing.Image]::FromStream($fs, $false, $false)

            function Get-PropertyValue([System.Drawing.Imaging.PropertyItem]$prop) {
                try {
                    switch ($prop.Type) {
                        2 { return ($encoding.GetString($prop.Value)).Trim([char]0) } # string
                        default { return $prop.Value }
                    }
                }
                catch { return $null }
            }

            foreach ($prop in $image.PropertyItems) {
                $val = Get-PropertyValue $prop
                switch ($prop.Id) {
                    0x010F { $data["CameraFabricante"] = $val }
                    0x0110 { $data["CameraModelo"] = $val }
                    0x0132 { $data["DataArquivo"] = $val }
                    0x9003 { $data["DataCaptura"] = $val }
                    0x8827 {
                        try { $data["ISO"] = [BitConverter]::ToInt16($prop.Value, 0) } catch { $data["ISO"] = $null }
                    }
                    0x829A {
                        if ($prop.Value.Length -ge 8) {
                            $n1 = [BitConverter]::ToInt32($prop.Value, 0)
                            $n2 = [BitConverter]::ToInt32($prop.Value, 4)
                            if ($n2 -ne 0) { $data["TempoExposicao"] = "$n1/$n2" }
                        }
                    }
                    0x829D {
                        if ($prop.Value.Length -ge 8) {
                            $n1 = [BitConverter]::ToInt32($prop.Value, 0)
                            $n2 = [BitConverter]::ToInt32($prop.Value, 4)
                            if ($n2 -ne 0) { $data["Abertura"] = [Math]::Round($n1 / $n2, 2) }
                        }
                    }
                }
            }

            $image.Dispose()
        }
        finally {
            $fs.Close()
        }
    }
    catch {
        # Em caso de erro, simplesmente retorna hashtable vazio
    }

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

    # Se largura do ListView ainda não estiver calculada, evita dividir por 0
    $w = $listView.ClientSize.Width
    if ($w -le 0) { return }

    $proportions = @(0.30, 0.18, 0.22, 0.12, 0.12, 0.06)

    for ($i = 0; $i -lt $listView.Columns.Count; $i++) {
        $colWidth = [int]([math]::Floor($w * $proportions[$i]))
        if ($colWidth -lt 80) { $colWidth = 80 }   # aumenta largura mínima
        $listView.Columns[$i].Width = $colWidth
    }
}

# ================================================================
# VARIÁVEIS DE ESTADO (usar $script: para manter escopo entre handlers)
# ================================================================
$script:previewData = [System.Collections.Generic.List[object]]::new()
$script:sourceFolder = $null
$script:destFolder = $null
$script:isExecuting = $false
$script:cancelRequested = $false

# ================================================================
# INTERFACE GRÁFICA
# - Form principal
# - Painel superior com botões (Dock = Top)
# - ListView que ocupa o restante (Dock = Fill)
# ================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "PicOrganizer - Organizador de Imagens"
$form.Size = New-Object System.Drawing.Size(900, 520)
$form.MinimumSize = New-Object System.Drawing.Size(900, 520)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# painel superior (controle dos botões e checkbox)
$topPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$topPanel.Dock = [System.Windows.Forms.DockStyle]::Top   # fica no topo
$topPanel.AutoSize = $true
$topPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$topPanel.WrapContents = $false
$topPanel.Padding = '8,8,8,8'
$topPanel.FlowDirection = 'LeftToRight'

# ListView principal (criado ANTES de adicionar controles ao form)
$listView = New-Object System.Windows.Forms.ListView
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.HideSelection = $false
$listView.Font = $form.Font
$listView.Dock = [System.Windows.Forms.DockStyle]::Fill   # ocupa tudo abaixo do topPanel

# colunas do ListView
$listView.Columns.Add("Nome Original", 200) | Out-Null
$listView.Columns.Add("Novo Nome", 150)     | Out-Null
$listView.Columns.Add("Destino", 150)      | Out-Null
$listView.Columns.Add("Data", 100)         | Out-Null
$listView.Columns.Add("Câmera", 120)       | Out-Null
$listView.Columns.Add("ISO", 80)           | Out-Null

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

# painel de status (texto em cima, barra embaixo)
$statusPanel = New-Object System.Windows.Forms.TableLayoutPanel
$statusPanel.ColumnCount = 1
$statusPanel.RowCount = 2
$statusPanel.AutoSize = $true
$statusPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$statusPanel.Margin = '20,6,6,6'

# linha 0: label de status
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Pronto"
$statusLabel.AutoSize = $true
$statusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusPanel.Controls.Add($statusLabel, 0, 0)

# linha 1: barra de progresso
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Width = 220
$progressBar.Height = 16
$progressBar.Style = 'Continuous'
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusPanel.Controls.Add($progressBar, 0, 1)

# adiciona o painel de status ao topo, depois dos botões
$topPanel.Controls.Add($statusPanel)


# ordem de adição é importante:
# 1º adiciona o painel superior
# 2º adiciona o ListView (Dock = Fill) – ele usa o espaço restante
$form.Controls.Add($listView)
$form.Controls.Add($topPanel)

# ajustar colunas ao redimensionar e ao mostrar
$form.Add_Resize({ Adjust-ListViewColumns })
$form.Add_Shown({ Adjust-ListViewColumns })


# ================================================================
# EVENTO: Pré-visualizar
# - Prioridade para EXIF (DataCaptura ou DataArquivo)
# - Caso contrário, _SEM-DATA_
# - Popula $script:previewData e o ListView
# ================================================================
$btnPreview.Add_Click({
    try {
        $listView.Items.Clear()

        # previewData como lista genérica para melhor performance
        $script:previewData = [System.Collections.Generic.List[object]]::new()
        $statusLabel.Text = "Selecionando pastas..."
        $progressBar.Value = 0

        # Seleciona pastas de origem e destino
        $script:sourceFolder = Select-FolderDialog -Description "Selecione o diretório com as imagens"
        if (-not $script:sourceFolder) {
            [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de origem selecionado.")
            $statusLabel.Text = "Cancelado"
            return
        }

        $script:destFolder = Select-FolderDialog -Description "Selecione o diretório de destino"
        if (-not $script:destFolder) {
            [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de destino selecionado.")
            $statusLabel.Text = "Cancelado"
            return
        }

        $statusLabel.Text = "Lendo imagens..."

        # 1) Conta todas as imagens válidas para configurar a barra
        $allImages = Get-ChildItem -Path $script:sourceFolder -Recurse -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Extension -match '\.(jpe?g|png|tiff?)$' }

        $totalPreview = $allImages.Count
        if ($totalPreview -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Nenhuma imagem encontrada no diretório selecionado.")
            $statusLabel.Text = "Nenhuma imagem"
            $progressBar.Value = 0
            return
        }

        $progressBar.Minimum = 0
        $progressBar.Maximum = $totalPreview
        $progressBar.Value   = 0

        # 2) Processa cada imagem, atualizando a barra
        $indexPreview = 0

        foreach ($img in $allImages) {
            $indexPreview++
            $progressBar.Value = $indexPreview

            # 1) Lê os metadados EXIF da imagem atual.
            $exif = Get-ExifData -FilePath $img.FullName
            if (-not $exif) { $exif = @{} }

            # 2) Define string de data (DataCaptura -> DataArquivo).
            $dateString = $null
            if ($exif.ContainsKey("DataCaptura") -and $exif["DataCaptura"]) {
                $dateString = $exif["DataCaptura"]
            }
            elseif ($exif.ContainsKey("DataArquivo") -and $exif["DataArquivo"]) {
                $dateString = $exif["DataArquivo"]
            }

            # 3) Valores padrão para SEM DATA.
            $mesano   = "_SEM-DATA_"   # pasta
            $nomeData = "_SEM-DATA_"   # base do nome do arquivo

            # 4) Se houver data, tenta extrair ano/mês/dia e validar.
            if ($dateString -and $dateString -match '(\d{4})[:\-](\d{2})[:\-](\d{2})') {

                $ano = $matches[1]
                $mes = $matches[2]
                $dia = $matches[3]

                if ($ano.Length -eq 4 -and $mes.Length -eq 2 -and $dia.Length -eq 2) {
                    $dataStr = '{0}-{1}-{2}' -f $ano, $mes, $dia

                    try {
                        $outDate = [DateTime]::ParseExact(
                            $dataStr,
                            'yyyy-MM-dd',
                            [System.Globalization.CultureInfo]::InvariantCulture
                        )

                        # Pasta: MMYYYY (ex.: 062015)
                        $mesano = '{0}{1}' -f $outDate.ToString('MM'), $outDate.ToString('yyyy')

                        # Nome do arquivo: dd-MM-yyyy (ex.: 10-06-2015)
                        $nomeData = $outDate.ToString('dd-MM-yyyy')
                    }
                    catch {
                        # mantém _SEM-DATA_
                    }
                }
            }

            # 5) Monta novo nome e diretório de destino.
            $ext       = $img.Extension.ToLower()
            $baseName  = $nomeData
            $finalDest = Join-Path $script:destFolder $mesano

            # 6) Adiciona ao previewData (List[object]).
            $script:previewData.Add([PSCustomObject]@{
                Original = $img.FullName
                BaseName = $baseName
                Ext      = $ext
                Destino  = $finalDest
                Data     = SafeSubItem($exif["DataCaptura"])
                Camera   = SafeSubItem($exif["CameraModelo"])
                ISO      = SafeSubItem($exif["ISO"])
            }) | Out-Null

            # 7) Cria item visual no ListView.
            $origDisplay   = $img.Name
            $newDisplay    = "$baseName$ext"
            $destDisplay   = $mesano
            $dataDisplay   = SafeSubItem($exif["DataCaptura"])
            $cameraDisplay = SafeSubItem($exif["CameraModelo"])
            $isoDisplay    = SafeSubItem($exif["ISO"])

            $lvi = New-Object System.Windows.Forms.ListViewItem($origDisplay)
            [void]$lvi.SubItems.Add($newDisplay)
            [void]$lvi.SubItems.Add($destDisplay)
            [void]$lvi.SubItems.Add($dataDisplay)
            [void]$lvi.SubItems.Add($cameraDisplay)
            [void]$lvi.SubItems.Add($isoDisplay)
            [void]$listView.Items.Add($lvi)
        }

        Adjust-ListViewColumns

        # Estatísticas para o status
        $total   = $script:previewData.Count
        $semData = $script:previewData.Where({ $_.BaseName -like '_SEM-DATA_*' }).Count

        $statusLabel.Text = "Pré-visualização: $total imagens ($semData sem data)"
        $progressBar.Value = $progressBar.Maximum
        [System.Windows.Forms.MessageBox]::Show("Pré-visualização concluída. Verifique a tabela antes de executar.")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erro durante a pré-visualização: `n$($_.Exception.Message)")
        $statusLabel.Text = "Erro"
        $progressBar.Value = 0
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

            $totalExec = $script:previewData.Count
            $progressBar.Minimum = 0
            $progressBar.Maximum = $totalExec
            $progressBar.Value = 0
            $processadas = 0

            $total = $script:previewData.Count   # total de imagens a processar
            $processadas = 0                     # contador de concluídas

            try {
                foreach ($entry in $script:previewData) {
                    if ($script:cancelRequested) {
                        $log += "Operação cancelada pelo usuário em $(Get-Date -Format o)"
                        break
                    }
                    
                    $processadas++
                    $progressBar.Value = $processadas
                    $statusLabel.Text = "Executando: $processadas / $totalExec imagens..."

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
                        Start-Sleep -Milliseconds 5
                    }
                    catch {
                        $log += "Erro ao mover ${orig}: $($_.Exception.Message)"
                    }
                }

                if ($script:cancelRequested) {
                    [System.Windows.Forms.MessageBox]::Show("Operação cancelada. Alguns arquivos podem ter sido movidos.")
                    $statusLabel.Text = "Cancelado: $processadas / $totalExec imagens"
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show("Processo concluído.")
                    $statusLabel.Text = "Concluído: $totalExec imagens processadas"
                }

                $progressBar.Value = 0   # reseta para o próximo uso


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
