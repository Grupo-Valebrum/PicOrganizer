# ProjetoX - Organizador de Imagens por EXIF
# Autor: Nelson Brum
# Colaborador: Jonathas Cunha
# Versão: 0.3
# Data: 2025-10-01

# ================================================================
# Configuração inicial
# ================================================================
# Define o encoding de saída para UTF-8, evitando problemas com acentuação
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Importa as bibliotecas necessárias do Windows Forms e System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ================================================================
# Função: Select-FolderDialog
# Descrição: Exibe uma janela para o usuário selecionar uma pasta
# Parâmetros: $Description → mensagem exibida na janela
# Retorno: Caminho selecionado ou $null
# ================================================================
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

# ================================================================
# Função: Get-ExifData
# Descrição: Extrai informações EXIF de uma imagem (quando disponíveis)
# Parâmetros: $FilePath → caminho da imagem
# Retorno: Hashtable com dados EXIF relevantes ou vazio
# ================================================================
function Get-ExifData {
    param([string]$FilePath)

    $image = [System.Drawing.Image]::FromFile($FilePath)
    $encoding = [System.Text.Encoding]::ASCII
    $data = @{}

    # Função interna para converter os dados do EXIF em formato legível
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
            0x010F { $data["CameraFabricante"] = $val }   # Fabricante da câmera
            0x0110 { $data["CameraModelo"] = $val }       # Modelo da câmera
            0x0132 { $data["DataArquivo"] = $val }        # Data do arquivo
            0x9003 { $data["DataCaptura"] = $val }        # Data de captura
            0x8827 { $data["ISO"] = if ($val) { [BitConverter]::ToInt16($prop.Value,0) } else { $null } }
            0x829A { # Tempo de exposição
                if ($prop.Value.Length -ge 8) {
                    $data["TempoExposicao"] = [BitConverter]::ToInt32($prop.Value,0).ToString() + "/" + [BitConverter]::ToInt32($prop.Value,4).ToString()
                }
            }
            0x829D { # Abertura
                if ($prop.Value.Length -ge 8) {
                    $data["Abertura"] = [Math]::Round([BitConverter]::ToInt32($prop.Value,0) / [BitConverter]::ToInt32($prop.Value,4),2)
                }
            }
        }
    }

    $image.Dispose()
    return $data
}

# ================================================================
# Função: SafeSubItem
# Descrição: Evita erro no ListView substituindo valores nulos por "N/A"
# ================================================================
function SafeSubItem($value) {
    if ($value) { return $value } else { return "N/A" }
}

# ================================================================
# Variáveis globais
# ================================================================
$previewData = @()
$sourceFolder = $null
$destFolder = $null

# ================================================================
# Formulário principal
# ================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProjetoX - Organizador de Imagens"
$form.Size = New-Object System.Drawing.Size(900,500)
$form.StartPosition = "CenterScreen"

# Checkbox para salvar logs
$chkLog = New-Object System.Windows.Forms.CheckBox
$chkLog.Text = "Salvar log das mudanças"
$chkLog.Location = New-Object System.Drawing.Point(20,20)
$chkLog.AutoSize = $true
$form.Controls.Add($chkLog)

# Botões principais
$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = "Pré-visualizar"
$btnPreview.Location = New-Object System.Drawing.Point(20,60)
$btnPreview.Width = 150
$form.Controls.Add($btnPreview)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Executar Mudanças"
$btnRun.Location = New-Object System.Drawing.Point(200,60)
$btnRun.Width = 150
$form.Controls.Add($btnRun)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Location = New-Object System.Drawing.Point(380,60)
$btnCancel.Width = 150
$form.Controls.Add($btnCancel)

# ListView dinâmico (responsivo ao redimensionamento da janela)
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20,110)
$listView.Size = New-Object System.Drawing.Size(840,320)
$listView.Anchor = "Top,Bottom,Left,Right"  
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Columns.Add("Nome Original",200) | Out-Null
$listView.Columns.Add("Novo Nome",150) | Out-Null
$listView.Columns.Add("Destino",150) | Out-Null
$listView.Columns.Add("Data",100) | Out-Null
$listView.Columns.Add("Câmera",120) | Out-Null
$listView.Columns.Add("ISO",80) | Out-Null
$form.Controls.Add($listView)

# ================================================================
# Evento: Pré-visualizar
# ================================================================
$btnPreview.Add_Click({
    $listView.Items.Clear()
    $previewData = @()

    # Seleção de pastas
    $sourceFolder = Select-FolderDialog -Description "Selecione o diretório com as imagens"
    if (-not $sourceFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de origem selecionado."); return }

    $destFolder = Select-FolderDialog -Description "Selecione o diretório de destino"
    if (-not $destFolder) { [System.Windows.Forms.MessageBox]::Show("Nenhum diretório de destino selecionado."); return }

    # Lista todos os arquivos suportados
    $images = Get-ChildItem -Path $sourceFolder -Include *.jpg,*.jpeg,*.png,*.tiff -File -Recurse

    foreach ($img in $images) {
        $exif = Get-ExifData -FilePath $img.FullName
        $mesano = "_SEM-DATA_"

        # 1) Tenta usar data do EXIF
        $date = if ($exif["DataCaptura"]) { $exif["DataCaptura"] } elseif ($exif["DataArquivo"]) { $exif["DataArquivo"] } else { $null }

        if ($date -and $date -match "(\d{4}):(\d{2}):(\d{2})") {
            $ano = $matches[1]
            $mes = $matches[2]
            $mesano = "$mes$ano"
        }

        # 2) Se não houver EXIF, tenta extrair data do nome do arquivo (AAAA-MM-DD)
        elseif ($img.Name -match "(\d{4})-(\d{2})-(\d{2})") {
            $ano = $matches[1]
            $mes = $matches[2]
            $mesano = "$mes$ano"
        }

        # Define novo nome e destino
        $newName = "$mesano$($img.Extension)"
        $finalDest = Join-Path $destFolder $mesano

        # Guarda no preview
        $previewData += [PSCustomObject]@{
            Original = $img.FullName
            NovoNome = $newName
            Destino  = $finalDest
            Data     = SafeSubItem $exif["DataCaptura"]
            Camera   = SafeSubItem $exif["CameraModelo"]
            ISO      = SafeSubItem $exif["ISO"]
        }

        # Adiciona no ListView
        $item = New-Object System.Windows.Forms.ListViewItem($img.Name)
        $item.SubItems.Add($newName) | Out-Null
        $item.SubItems.Add($mesano) | Out-Null
        $item.SubItems.Add((SafeSubItem $exif["DataCaptura"])) | Out-Null
        $item.SubItems.Add((SafeSubItem $exif["CameraModelo"])) | Out-Null
        $item.SubItems.Add((SafeSubItem $exif["ISO"])) | Out-Null
        $listView.Items.Add($item) | Out-Null
    }

    [System.Windows.Forms.MessageBox]::Show("Pré-visualização concluída.")
})

# ================================================================
# Evento: Executar mudanças
# ================================================================
$btnRun.Add_Click({
    if (-not $previewData -or $previewData.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nenhuma pré-visualização realizada. Clique em 'Pré-visualizar' primeiro.")
        return
    }

    $log = @()

    foreach ($item in $previewData) {
        try {
            if (-not (Test-Path $item.Destino)) {
                New-Item -Path $item.Destino -ItemType Directory | Out-Null
            }
            $destFile = Join-Path $item.Destino $item.NovoNome
            Move-Item -Path $item.Original -Destination $destFile -Force

            $log += "Movido: ${item.Original} -> $destFile"
            $log += "EXIF: Data=${item.Data} Camera=${item.Camera} ISO=${item.ISO}"
            $log += "----"
        }
        catch {
            $log += "Erro ao mover ${item.Original}: $($_.Exception.Message)"
        }
    }

    if ($chkLog.Checked -and $log.Count -gt 0) {
        $logFile = Join-Path $destFolder ("log_EXIF_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")
        $log | Out-File -FilePath $logFile -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Processo concluído. Log salvo em: `n$logFile")
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Processo concluído.")
    }
})

# ================================================================
# Evento: Cancelar
# ================================================================
$btnCancel.Add_Click({
    $form.Close()
})

# ================================================================
# Executa o formulário
# ================================================================
[void]$form.ShowDialog()
