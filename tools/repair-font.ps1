$ErrorActionPreference = 'Stop'
# Preserve the original font and repair its malformed Mac Roman cmap length.
$fontDirectory = Join-Path $PSScriptRoot '../fonts'
$sourcePath = Join-Path $fontDirectory 'BOREDSB.TTF'
$outputPath = Join-Path $fontDirectory 'BOREDSB-web.ttf'
$fontBytes = [IO.File]::ReadAllBytes($sourcePath)

function Read-U16([int]$offset) {
    return [int]$fontBytes[$offset] * 256 + $fontBytes[$offset + 1]
}
function Read-U32([int]$offset) {
    return [long]$fontBytes[$offset] * 16777216 + [long]$fontBytes[$offset + 1] * 65536 + [long]$fontBytes[$offset + 2] * 256 + $fontBytes[$offset + 3]
}
function Write-U32([int]$offset, [long]$value) {
    $fontBytes[$offset] = ($value -shr 24) -band 255
    $fontBytes[$offset + 1] = ($value -shr 16) -band 255
    $fontBytes[$offset + 2] = ($value -shr 8) -band 255
    $fontBytes[$offset + 3] = $value -band 255
}
function Get-Checksum([int]$offset, [int]$length) {
    [long]$sum = 0
    for ($i = 0; $i -lt $length; $i += 4) {
        [long]$word = 0
        for ($j = 0; $j -lt 4; $j++) {
            $word *= 256
            if ($i + $j -lt $length) { $word += $fontBytes[$offset + $i + $j] }
        }
        $sum = ($sum + $word) % 4294967296
    }
    return $sum
}

$tables = @{}
for ($i = 0; $i -lt (Read-U16 4); $i++) {
    $entry = 12 + 16 * $i
    $tag = [Text.Encoding]::ASCII.GetString($fontBytes, $entry, 4)
    $tables[$tag] = @{ Entry = $entry; Offset = (Read-U32 ($entry + 8)); Length = (Read-U32 ($entry + 12)) }
}
$cmap = $tables['cmap']
$head = $tables['head']
if (-not $cmap -or -not $head) { throw 'Required font tables are missing.' }
$subtable = $cmap.Offset + (Read-U32 ($cmap.Offset + 8))
if ((Read-U16 ($cmap.Offset + 4)) -ne 1 -or (Read-U16 $subtable) -ne 0 -or (Read-U16 ($subtable + 2)) -ne 0) {
    throw 'Unexpected source font; refusing to modify it.'
}
$fontBytes[$subtable + 2] = 1
$fontBytes[$subtable + 3] = 6
Write-U32 ($head.Offset + 8) 0
Write-U32 ($cmap.Entry + 4) (Get-Checksum $cmap.Offset $cmap.Length)
Write-U32 ($head.Entry + 4) (Get-Checksum $head.Offset $head.Length)
$adjustment = (2981146554 - (Get-Checksum 0 $fontBytes.Length) + 4294967296) % 4294967296
Write-U32 ($head.Offset + 8) $adjustment
if ((Get-Checksum 0 $fontBytes.Length) -ne 2981146554) { throw 'Invalid font checksum.' }
[IO.File]::WriteAllBytes($outputPath, $fontBytes)
Write-Output "Repaired font saved to $outputPath"
