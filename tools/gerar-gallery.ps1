# Atualiza automaticamente images/gallery/manifest.json
# Execute este arquivo sempre que adicionar ou remover fotos da pasta gallery.

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Gallery = Join-Path $ProjectRoot "images\gallery"
$Manifest = Join-Path $Gallery "manifest.json"

if (-not (Test-Path $Gallery)) {
    Write-Error "Pasta não encontrada: $Gallery"
    exit 1
}

$extensions = @(
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
    ".avif"
)

$files = Get-ChildItem -Path $Gallery -File |
    Where-Object {
        $extensions -contains $_.Extension.ToLowerInvariant()
    } |
    Sort-Object Name |
    ForEach-Object {
        $_.Name
    }

$json = ConvertTo-Json -InputObject @($files)

# Grava UTF-8 sem BOM para funcionar bem no navegador.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Manifest, $json, $utf8NoBom)

Write-Host ""
Write-Host "Galeria atualizada com sucesso."
Write-Host "$($files.Count) imagem(ns) encontrada(s)."
Write-Host "Manifest: $Manifest"
Write-Host ""
