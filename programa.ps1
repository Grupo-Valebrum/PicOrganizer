# ProjetoX - Organizador de Imagens
# Autor: Nelson Brum
# Colaborador: Jonathas
# Versão: 0.2.1
# Data: 2025-10-01
#
# Observações (minhas anotações):
# - Este script fornece interface gráfica para pré-visualizar e mover imagens
#   organizando-as por mês/ano (MMAAAA). Imagens sem EXIF recebem nome _SEM-DATA_.
# - O ListView é responsivo e o Cancel interrompe execuções em andamento.
# - Execução: powershell -ExecutionPolicy Bypass -File .\ProjetoX.ps1

# --- Forçar saída do console em UTF-8 para evitar caracteres estranhos ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Importar assemblies do Windows Forms e Drawing (obrigatório antes de usar Application) ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Ativar estilos visuais do Windows Forms ---
[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------------------------------------
# Minha função: Select-FolderDialog
# Uso: Abre um diálogo para o usuário escolher uma pasta.
# Racional: centralizo em função para reaproveitar em origem/destino.
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# Minha função: Get-ExifData
# Uso: Retorna um hashtable com campos EXIF extraídos da imagem.
# Observação: uso UTF8 para tentar preservar acentuação nas strings EXIF.
# ------------------------------------------------------------
function Get-ExifData {
    param([string]$FilePath)

    # Abro a imagem e leio PropertyItems
    $image = [System.Drawing.Image]::FromFile($FilePath)
    $encoding = [System.Text.Encoding]::UTF8
    $data = @{}

    function Get-PropertyValue([System.Drawing.Imaging.PropertyItem]$prop) {
        try {
            switch ($prop.Type) {
                2 { return ($encoding.GetString($prop.Value)).Trim([char]0) } # String
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
                    $num1 = [BitConverter]::ToInt32($prop.Value,0)
                    $num2 = [BitConverter]::ToInt32($prop.Value,4)
                    if ($num2 -ne 0) {
                        $data["TempoExposicao"] = "$num1/$num2"
                    }
                }
            }
            0x829D { 
                if ($prop.Value.Length -ge 8) {
                    $n1 = [BitConverter]::ToInt32($prop.Value,0)
                    $n2 = [BitConverter]::ToInt32($prop.Value,4)
                    if ($n2 -ne 0) {
                        $data["Abertura"] = [Math]::Round($n1 / $n2,2)
                    }
                }
            }
        }
    }

    $image.Dispose()
    return $data
}

# ------------------------------------------------------------
# Minha função: SafeSubItem
# Uso: garantir string não-nula para exibição no ListView.
# ------------------------------------------------------------
function SafeSubItem {
    param($value)
    if ($null -ne $value -and $value -ne "") { return $value } else { return "N/A" }
}

# ------------------------------------------------------------
# Minha função: Get-UniqueFilename
# Uso: Garante que o nome gerado seja único no diretório de destino,
#       adicionando sufixo _1, _2... quando necessário.
# Entrada: $destDir, $baseName (sem extensão), $ext (com ponto ex: .jpg)
# Retorno: nome único (ex: 092025.jpg ou 092025_1.jpg)
# ------------------------------------------------------------
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

# --- Variáveis de estado compartilhadas ---
$previewData = @()
$sourceFolder = $null
$destFolder = $null
$isExecuting = $false
$cancelRequested = $false

# ------------------------------------------------------------
# Formulário principal - configuração visual
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProjetoX - Organizador de Imagens"    # Título pedido
$form.Size = New-Object System.Drawing.Size(900,520)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)  # fonte Unicode moderna

# Painel superior para controles (flow para responsividade)
$topPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$topPanel.Dock = 'Top'
$topPanel.AutoSize = $true
$topPanel.WrapContents = $false
$topPanel.Padding = '8,8,8,8'
$topPanel.FlowDirection = 'LeftToRight'
$form.Controls.Add($topPanel)

# Checkbox para logs
$chkLog = New-Object System.Windows.Forms.CheckBox
$chkLog.Text = "Salvar log das mudanças"
$chkLog.AutoSize = $true
$topPanel.Controls.Add($chkLog)

# Botões
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

# Label de status ao lado direito (expande)
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Pronto"
$statusLabel.AutoSize = $true
$statusLabel.Margin = '20,6,6,6'
$topPanel.Controls.Add($statusLabel)

# ListView preenchendo o restante da janela (dock fill)
$listView = New-Object System.Windows.Forms.ListView
$listView.Dock = 'Fill'
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.HideSelection = $false
$listView.Font = $form.Font

# Colunas iniciais (larguras serão ajustadas dinamicamente)
$listView.Columns.Add("Nome Original",200) | Out-Null
$listView.Columns.Add("Novo Nome",150) | Out-Null
$listView.Columns.Add("Destino",150) | Out-Null
$listView.Columns.Add("Data",100) | Out-Null
$listView.Columns.Add("Câmera",120) | Out-Null
$listView.Columns.Add("ISO",80) | Out-Null

$form.Controls.Add($listView)

# Ajuste das colunas proporcionalmente ao redimensionar a janela
function Adjust-ListViewColumns {
    # proporções por coluna (soma ~1.0)
    $proportions = @(0.30, 0.18, 0.22, 0.12, 0.12, 0.06)
    $w = $listView.ClientSize.Width
    for ($i = 0; $i -lt $listView.Columns.Count; $i++) {
        $colWidth = [int]([math]::Floor($w * $proportions[$i]))
        # largura mínima razoável
        if ($colWidth -lt 40) { $colWidth = 40 }
        $listView.Columns[$i].Width = $colWidth
    }
}

# ligar o evento Resize do formulário para ajustar colunas
$form.Add_Resize({ Adjust-ListViewColumns })

# Também ajustar ao inicializar
$form.Add_Shown({ Adjust-ListViewColumns })

# ------------------------------------------------------------
# Evento: Pré-visualizar
# Lógica: percorre as imagens, extrai EXIF, gera previewData e popula o ListView.
# ------------------------------------------------------------
$btnPreview.Add_Click({
    try {
        $listView.Items.Clear()
        $previewData = @()
        $statusLabel.Text = "Selecionando pastas..."

        $sourceFolder = Select-FolderDialog -Description "Selecione o diretório com as imagens"
        if (-not $sourceFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de origem selecionado."); $statusLabel.Text = "Cancelado"; return }

        $destFolder = Select-FolderDialog -Description "Selecione o diretório de destino"
        if (-not $destFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de destino selecionado."); $statusLabel.Text = "Cancelado"; return }

        $statusLabel.Text = "Lendo imagens..."
        $images = Get-ChildItem -Path $sourceFolder -Include *.jpg,*.jpeg,*.png,*.tiff -File -Recurse -ErrorAction SilentlyContinue

        if (-not $images -or $images.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Nenhuma imagem encontrada no diretório selecionado.")
            $statusLabel.Text = "Nenhuma imagem"
            return
        }

        foreach ($img in $images) {
            $exif = Get-ExifData -FilePath $img.FullName
            $mesano = "_SEM-DATA_"

            # Determino MESANO se houver data EXIF
            $date = if ($exif.ContainsKey("DataCaptura") -and $exif["DataCaptura"]) { $exif["DataCaptura"] } elseif ($exif.ContainsKey("DataArquivo") -and $exif["DataArquivo"]) { $exif["DataArquivo"] } else { $null }

            if ($date -and $date -match "(\d{4}):(\d{2}):(\d{2})") {
                $ano = $matches[1]
                $mes = $matches[2]
                $mesano = "$mes$ano"
            }

            # Novo nome base (sem repetição do nome original), ext inclui o ponto
            $ext = $img.Extension.ToLower()
            $baseName = $mesano
            # Preparo destino (a criação real de pasta só ocorre no Execute)
            $finalDest = Join-Path $destFolder $mesano

            # adicionar ao previewData (dados para executar depois)
            $previewData += [PSCustomObject]@{
                Original = $img.FullName
                BaseName = $baseName
                Ext = $ext
                Destino  = $finalDest
                Data     = SafeSubItem($exif["DataCaptura"])
                Camera   = SafeSubItem($exif["CameraModelo"])
                ISO      = SafeSubItem($exif["ISO"])
            }

            # Popular ListView (uso variáveis temporárias para evitar parsing problems)
            $origDisplay = $img.Name
            $newDisplay = "$baseName$ext"
            $destDisplay = $mesano
            $dataDisplay = SafeSubItem($exif["DataCaptura"])
            $cameraDisplay = SafeSubItem($exif["CameraModelo"])
            $isoDisplay = SafeSubItem($exif["ISO"])

            $item = New-Object System.Windows.Forms.ListViewItem($origDisplay)
            [void]$item.SubItems.Add($newDisplay)
            [void]$item.SubItems.Add($destDisplay)
            [void]$item.SubItems.Add($dataDisplay)
            [void]$item.SubItems.Add($cameraDisplay)
            [void]$item.SubItems.Add($isoDisplay)
            [void]$listView.Items.Add($item)
        }

        Adjust-ListViewColumns
        $statusLabel.Text = "Pré-visualização concluída. {0} imagens." -f $previewData.Count
        [System.Windows.Forms.MessageBox]::Show("Pré-visualização concluída. Verifique a tabela antes de executar.")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erro durante a pré-visualização: `n$_")
        $statusLabel.Text = "Erro"
    }
})

# ------------------------------------------------------------
# Evento: Executar Mudanças
# Lógica: percorre $previewData, cria pastas, gera nomes únicos e move arquivos.
# Possui suporte a cancelamento cooperativo.
# ------------------------------------------------------------
$btnRun.Add_Click({
    if (-not $previewData -or $previewData.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nenhuma pré-visualização realizada. Clique em 'Pré-visualizar' primeiro.")
        return
    }

    # Estado e UI
    $isExecuting = $true
    $cancelRequested = $false
    $btnPreview.Enabled = $false
    $btnRun.Enabled = $false
    $statusLabel.Text = "Executando..."
    $log = @()

    try {
        foreach ($entry in $previewData) {
            # Checar se usuário solicitou cancelamento
            if ($cancelRequested) {
                $log += "Operação cancelada pelo usuário em $(Get-Date -Format o)"
                break
            }

            $orig = $entry.Original
            $destDir = $entry.Destino
            $baseName = $entry.BaseName
            $ext = $entry.Ext

            # Certificar existência da pasta destino
            if (-not (Test-Path $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }

            # Gerar nome único para evitar sobrescrita
            $uniqueName = Get-UniqueFilename -destDir $destDir -baseName $baseName -ext $ext
            $destFile = Join-Path $destDir $uniqueName

            try {
                Move-Item -Path $orig -Destination $destFile -Force
                $log += "Movido: $orig -> $destFile"
                $log += "EXIF: Data=$($entry.Data) Camera=$($entry.Camera) ISO=$($entry.ISO)"
                $log += "----"
                $statusLabel.Text = "Movendo: $uniqueName"
                Start-Sleep -Milliseconds 50  # dá chance ao UI de atualizar (responsividade)
            }
            catch {
                $log += "Erro ao mover $orig: $_"
            }
        }

        if ($cancelRequested) {
            [System.Windows.Forms.MessageBox]::Show("Operação cancelada. Alguns arquivos já podem ter sido movidos.")
            $statusLabel.Text = "Cancelado"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Processo concluído.")
            $statusLabel.Text = "Concluído"
        }

        # Salvar log se solicitado
        if ($chkLog.Checked -and $log.Count -gt 0) {
            $logFile = Join-Path $destFolder ("log_EXIF_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
            $log | Out-File -FilePath $logFile -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Log salvo em:`n$logFile")
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erro durante a execução: `n$_")
        $statusLabel.Text = "Erro"
    }
    finally {
        # restaurar UI
        $isExecuting = $false
        $cancelRequested = $false
        $btnPreview.Enabled = $true
        $btnRun.Enabled = $true
    }
})

# ------------------------------------------------------------
# Evento: Cancelar
# Comportamento:
# - Se não há execução em curso: limpa a pré-visualização e reseta variáveis.
# - Se há execução: sinaliza cancelRequested e espera que o loop pare.
# ------------------------------------------------------------
$btnCancel.Add_Click({
    if ($isExecuting) {
        # sinalizo cancelamento; o laço de execução verifica essa variável
        $cancelRequested = $true
        $statusLabel.Text = "Cancelando..."
        [System.Windows.Forms.MessageBox]::Show("Pedido de cancelamento enviado. Ação será interrompida em breve.")
    }
    else {
        # apenas limpar preview e manter o programa aberto
        $listView.Items.Clear()
        $previewData = @()
        $sourceFolder = $null
        $destFolder = $null
        $statusLabel.Text = "Pré-visualização limpa"
        [System.Windows.Forms.MessageBox]::Show("Pré-visualização limpa. Nenhuma mudança foi realizada.")
    }
})

# ------------------------------------------------------------
# Mostrar o formulário (inicia a interface)
# ------------------------------------------------------------
[void]$form.ShowDialog()
