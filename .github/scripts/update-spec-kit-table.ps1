#Requires -Version 7
<#
.SYNOPSIS
Übernimmt die veröffentlichte Level-0-Tabelle. / Imports the published Level-0 table.
.DESCRIPTION
Reads public files pinned to one Level-0 commit. Verifies the exported table hash
and replaces only one marked profile block. No commit, push or merge.
Liest gepinnte öffentliche Dateien und ersetzt nur den Tabellenblock.
.PARAMETER SourceDirectory
Optional offline fixture/export directory for testing. / Optionales Offline-Verzeichnis.
.PARAMETER Readme
Target README path. / README-Zielpfad.
.PARAMETER CheckOnly
Reports drift without writing. / Meldet Drift ohne Schreiben.
.EXAMPLE
pwsh -NoProfile -File .github/scripts/update-spec-kit-table.ps1 -CheckOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourceDirectory,
    [string]$Readme = (Join-Path $PSScriptRoot '../../README.md'),
    [switch]$CheckOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-SourceFile {
    param([string]$Path, [string]$Commit)
    $json = & gh api --hostname github.com --method GET "repos/hindermath/home-baseline/contents/docs/spec-kit-runs/${Path}?ref=$Commit"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read published public source.' }
    $file = $json | ConvertFrom-Json
    if ($file.type -ne 'file' -or $file.encoding -ne 'base64' -or $file.size -gt 100000) { throw 'Invalid publication file.' }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content))
}

function Test-AccessibleTable {
    param([string]$Table, [string[]]$Headers)
    # Treat the new presentation as data, not arbitrary HTML. XML parsing is
    # bounded and cannot resolve a DTD or an external resource.
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.MaxCharactersInDocument = 100000
    $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Table), $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
    } finally { $reader.Dispose() }
    $attributes = @{
        div = @('lang'); table = @('aria-label', 'lang'); caption = @()
        thead = @(); tbody = @(); tr = @(); th = @('scope'); td = @('align')
        a = @('href'); strong = @()
    }
    foreach ($element in $document.SelectNodes('//*')) {
        if (-not $attributes.ContainsKey($element.Name)) { throw 'Unexpected HTML element.' }
        foreach ($attribute in $element.Attributes) {
            if ($attribute.Name -cnotin $attributes[$element.Name]) { throw 'Unexpected HTML attribute.' }
            if ($attribute.Name -eq 'href' -and $attribute.Value -cnotmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository link.' }
            if ($attribute.Name -eq 'lang' -and $attribute.Value -cne 'de') { throw 'Expected German publication.' }
            if ($attribute.Name -eq 'align' -and $attribute.Value -cne 'right') { throw 'Unexpected numeric alignment.' }
        }
    }
    if ($document.DocumentElement.Name -cne 'div' -or $document.DocumentElement.GetAttribute('lang') -cne 'de') { throw 'Missing publication language.' }
    $tables = $document.SelectNodes('/div/table')
    if ($tables.Count -ne 1 -or [string]::IsNullOrWhiteSpace($tables[0].GetAttribute('aria-label'))) { throw 'One named table is required.' }
    $columns = $document.SelectNodes('/div/table/thead/tr/th')
    if ($columns.Count -ne $Headers.Count) { throw 'Unexpected table header count.' }
    for ($index = 0; $index -lt $columns.Count; $index++) {
        if ($columns[$index].InnerText -cne $Headers[$index] -or $columns[$index].GetAttribute('scope') -cne 'col') { throw 'Invalid column heading.' }
    }
    $rows = $document.SelectNodes('/div/table/tbody/tr')
    if ($rows.Count -lt 1) { throw 'Missing repository rows.' }
    foreach ($row in $rows) {
        $cells = $row.SelectNodes('th|td')
        if ($cells.Count -ne $Headers.Count -or $row.SelectNodes('th').Count -ne 1 -or
            $cells[0].Name -cne 'td' -or $cells[1].Name -cne 'th' -or $cells[1].GetAttribute('scope') -cne 'row' -or
            [string]::IsNullOrWhiteSpace($cells[1].InnerText)) { throw 'Invalid row heading or column count.' }
        for ($index = 2; $index -lt $cells.Count; $index++) {
            if ($cells[$index].Name -cne 'td') { throw 'Expected data cell.' }
        }
    }
}
try {
    if ($SourceDirectory) {
        $table = [IO.File]::ReadAllText((Join-Path $SourceDirectory 'table.md'))
        $manifest = [IO.File]::ReadAllText((Join-Path $SourceDirectory 'publication.json')) | ConvertFrom-Json
        $commit = 'offline-test'
    } else {
        $raw = & gh api --hostname github.com --method GET repos/hindermath/home-baseline
        if ($LASTEXITCODE -ne 0) { throw 'Cannot verify public source visibility.' }
        $meta = $raw | ConvertFrom-Json
        if ($meta.private -or $meta.visibility -ne 'public') { throw 'Source is not public.' }
        $commit = & gh api --hostname github.com --method GET "repos/hindermath/home-baseline/commits/$($meta.default_branch)" --jq .sha
        if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[a-f0-9]{40}$') { throw 'Cannot pin source commit.' }
        $table = Get-SourceFile table.md $commit
        $manifest = Get-SourceFile publication.json $commit | ConvertFrom-Json
    }
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($table))).ToLowerInvariant()
    if ($manifest.schemaVersion -notin @(1, 2, 3) -or $manifest.tableSha256 -cne $hash) { throw 'Publication checksum mismatch.' }
    $header = if ($manifest.schemaVersion -eq 1) { '| Level | Öffentliches GitHub-Repository | Gestartet | Ausgeführt | Abschluss belegt |' }
        else { '| Level | Öffentliches GitHub-Repository / Gruppe | Gestartet | Ausgeführt | Abschluss belegt | Manuell | Autonom seriell | Autonom parallel | Gemischt | Nicht eindeutig belegt |' }
    if ($manifest.schemaVersion -eq 3) { $header += ' Beschleunigungsfaktor (Repo-Schätzung) |' }
    $format = $manifest.PSObject.Properties['tableFormat']
    if ($null -ne $format) {
        if ($format.Value -cne 'accessible-html-v1') { throw 'Unknown table presentation.' }
        Test-AccessibleTable $table @($header.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    } elseif (-not $table.Contains($header)) { throw 'Invalid legacy table contract.' }
    if ($table.Contains('<!--') -or $table -match '<script|<iframe') { throw 'Invalid table contract.' }
    # Read the profile only after the source fetch to preserve independent MOTD edits.
    $text = [IO.File]::ReadAllText($Readme)
    $begin = '<!-- public-speckit-runs:begin -->'; $end = '<!-- public-speckit-runs:end -->'
    if ([regex]::Matches($text, [regex]::Escape($begin)).Count -ne 1 -or
        [regex]::Matches($text, [regex]::Escape($end)).Count -ne 1) { throw 'Exactly one marker pair is required.' }
    $start = $text.IndexOf($begin, [StringComparison]::Ordinal)
    $finish = $text.IndexOf($end, [StringComparison]::Ordinal)
    if ($finish -le $start) { throw 'Reversed table markers.' }
    $updated = $text.Substring(0, $start) + $begin + "`n" + $table.TrimEnd("`r", "`n") + "`n" + $text.Substring($finish)
    if ($env:GITHUB_OUTPUT -and -not $CheckOnly -and -not $WhatIfPreference) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "source_commit=$commit" -Encoding utf8
    }
    if ($updated -ceq $text) { Write-Host "CURRENT: $commit"; exit 0 }
    if ($CheckOnly) { Write-Host 'DRIFT: profile table.'; exit 1 }
    if ($PSCmdlet.ShouldProcess($Readme, 'Import verified public table')) { [IO.File]::WriteAllText($Readme, $updated, [Text.UTF8Encoding]::new($false)) }
    Write-Host "IMPORTED: $commit"
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 2
}
