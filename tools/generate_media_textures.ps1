param(
  [string]$AddonRoot = (Resolve-Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path)
)

$mediaDir = Join-Path $AddonRoot 'media'
$outFile  = Join-Path $AddonRoot 'fr0z3nUI_ArtLayer_Media.lua'

if (-not (Test-Path $mediaDir)) {
  throw "Media folder not found: $mediaDir"
}

$items = Get-ChildItem -Path $mediaDir -Filter '*.tga' -File | Sort-Object Name

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('---@diagnostic disable: undefined-global')
$lines.Add('')
$lines.Add('-- Auto-generated helper list for the UI texture picker.')
$lines.Add('-- WoW addons cannot enumerate files at runtime; regenerate when media changes.')
$lines.Add('')
$lines.Add('local ADDON, ns = ...')
$lines.Add('ns = ns or {}')
$lines.Add('')
$lines.Add('ns.MediaTextures = {')

foreach ($f in $items) {
  $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $label = $name
  if ($label -match '^PB\d+_') {
    $label = $label -replace '^PB\d+_', ''
  }

  $luaLabel = $label.Replace("\\", "\\\\").Replace("\"", "\\\"")
  $luaValue = $name.Replace("\\", "\\\\").Replace("\"", "\\\"")
  $lines.Add("  { \"$luaLabel\", \"$luaValue\" },")
}

$lines.Add('}')
$lines.Add('')

Set-Content -Path $outFile -Value $lines -Encoding UTF8
Write-Host "Wrote $($items.Count) textures to $outFile"
