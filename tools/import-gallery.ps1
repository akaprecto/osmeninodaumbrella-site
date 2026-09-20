$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$siteRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspaceRoot = Split-Path $siteRoot -Parent
$sourceFolders = @('Demais fotos-20260920T114142Z-1-001', 'Showcase-20260920T114933Z-1-001')
$destination = Join-Path $siteRoot 'images/gallery'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$sources = @(
  Get-Item -LiteralPath (Join-Path $siteRoot 'images/@juulios SUB0046.jpg')
  Get-Item -LiteralPath (Join-Path $siteRoot 'images/@juulios os menino.jpg')
  Get-Item -LiteralPath (Join-Path $siteRoot 'images/@SALLVADOR77 umbrellas.jpg')
  foreach ($folder in $sourceFolders) {
    Get-ChildItem -LiteralPath (Join-Path $workspaceRoot $folder) -Recurse -File |
      Where-Object { $_.Extension -match '^\.(jpe?g|png)$' } | Sort-Object FullName
  }
)
$seen = @{}
$manifest = [Collections.Generic.List[object]]::new()
$encoder = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$parameters = [Drawing.Imaging.EncoderParameters]::new(1)
$parameters.Param[0] = [Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality, [long]85)
try {
  foreach ($source in $sources) {
    $hash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
    if ($seen.ContainsKey($hash)) { continue }
    $seen[$hash] = $true
    $filename = 'foto-' + $hash.Substring(0,16).ToLowerInvariant() + '.jpg'
    $outputPath = Join-Path $destination $filename
    $image = [Drawing.Image]::FromFile($source.FullName)
    try {
      if ($image.PropertyIdList -contains 274) {
        $orientation = [BitConverter]::ToUInt16($image.GetPropertyItem(274).Value,0)
        $rotations = @{2='RotateNoneFlipX';3='Rotate180FlipNone';4='Rotate180FlipX';5='Rotate90FlipX';6='Rotate90FlipNone';7='Rotate270FlipX';8='Rotate270FlipNone'}
        if ($rotations.ContainsKey([int]$orientation)) { $image.RotateFlip([Drawing.RotateFlipType]::$($rotations[[int]$orientation])) }
      }
      $scale = [Math]::Min(1, 1800 / [Math]::Max($image.Width,$image.Height))
      $width = [Math]::Max(1,[int][Math]::Round($image.Width*$scale))
      $height = [Math]::Max(1,[int][Math]::Round($image.Height*$scale))
      $bitmap = [Drawing.Bitmap]::new($width,$height)
      $graphics = [Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($image,0,0,$width,$height)
        $bitmap.Save($outputPath,$encoder,$parameters)
      } finally { $graphics.Dispose(); $bitmap.Dispose() }
      $manifest.Add([pscustomobject]@{source=$source.FullName.Substring($workspaceRoot.Length+1);src="images/gallery/$filename";width=$width;height=$height;originalBytes=$source.Length;webBytes=(Get-Item -LiteralPath $outputPath).Length})
    } finally { $image.Dispose() }
  }
} finally { $parameters.Dispose() }
$htmlPath = Join-Path $siteRoot 'index.html'
$html = [IO.File]::ReadAllText($htmlPath)
$pages = for ($i=0; $i -lt $manifest.Count; $i++) {
  $item = $manifest[$i]
  $hidden = if ($i -eq 0) { '' } else { ' hidden' }
  '            <span class="gallery-page"' + $hidden + '><img src="' + $item.src + '" alt="Registro fotográfico do coletivo em evento — foto ' + ($i+1) + '" width="' + $item.width + '" height="' + $item.height + '" loading="lazy" decoding="async" draggable="false"></span>'
}
$pattern = '(?m)^\s*<span class="gallery-page"[^\r\n]+</span>\r?\n'
if ([regex]::Matches($html,$pattern).Count -lt 1) { throw 'Gallery markup not found.' }
$firstPage = [regex]::Match($html,$pattern).Index
$html = [regex]::Replace($html,$pattern,'')
$html = $html.Insert($firstPage, ($pages -join "`n") + "`n")
$html = [regex]::Replace($html,'(?<=aria-atomic="true">)Foto 1 de \d+',"Foto 1 de $($manifest.Count)")
[IO.File]::WriteAllText($htmlPath,$html,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $destination 'manifest.json'),($manifest | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{SourceFiles=$sources.Count;GalleryPhotos=$manifest.Count;DuplicatesSkipped=$sources.Count-$manifest.Count;OriginalMB=[Math]::Round(($manifest|Measure-Object originalBytes -Sum).Sum/1MB,1);WebMB=[Math]::Round(($manifest|Measure-Object webBytes -Sum).Sum/1MB,1)} | ConvertTo-Json
