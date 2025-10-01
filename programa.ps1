# ProjetoX - Organizador de Imagens
# Autor: Nelson Brum
# Colaborador: Jonathas Cunha
# Versão: 0.2
# Data: 2025-10-01

# --- Configuração de encoding para evitar caracteres estranhos ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Importar assemblies do Windows Forms e Drawing ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================================================================
# Função: Select-FolderDialog
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
function Get-ExifData {
    param([string]$FilePath)

    $image = [System.Drawing.Image]::FromFile($FilePath)
    $encoding = [System.Text.Encoding]::UTF8
    $data = @{}

    function Get-PropertyValue([System.Drawing.Imaging.PropertyItem]$prop) {
        try {
            switch ($prop.Type) {
                2 { return ($encoding.GetString($prop.Value)).Trim([char]0) } 
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
            0x8827 { $data["ISO"] = if ($val) { [BitConverter]::ToInt16($prop.Value,0) } else { $null } }
            0x829A { 
                if ($prop.Value.Length -ge 8) {
                    $data["TempoExposicao"] = [BitConverter]::ToInt32($prop.Value,0).ToString() + "/" + [BitConverter]::ToInt32($prop.Value,4).ToString()
                }
            }
            0x829D { 
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
function SafeSubItem($value) {
    if ($value) { return $value } else { return "N/A" }
}

# --- Variáveis globais ---
$previewData = @()
$sourceFolder = $null
$destFolder = $null

# ================================================================
# Formulário principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProjetoX - Organizador de Imagens"
$form.Size = New-Object System.Drawing.Size(900,500)
$form.StartPosition = "CenterScreen"

# --- Checkbox ---
$chkLog = New-Object System.Windows.Forms.CheckBox
$chkLog.Text = "Salvar log das mudanças"
$chkLog.Location = New-Object System.Drawing.Point(20,20)
$chkLog.AutoSize = $true
$form.Controls.Add($chkLog)

# --- Botões ---
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

# --- ListView responsivo ---
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20,110)
$listView.Size = New-Object System.Drawing.Size(840,320)
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Anchor = "Top,Bottom,Left,Right"   # <<< Responsividade
$listView.Columns.Add("Nome Original",200) | Out-Null
$listView.Columns.Add("Novo Nome",150) | Out-Null
$listView.Columns.Add("Destino",150) | Out-Null
$listView.Columns.Add("Data",100) | Out-Null
$listView.Columns.Add("Câmera",120) | Out-Null
$listView.Columns.Add("ISO",80) | Out-Null
$form.Controls.Add($listView)

# (Eventos permanecem iguais ao que você já tem)
# ================================================================
# Rodar formulário
[void]$form.ShowDialog()
