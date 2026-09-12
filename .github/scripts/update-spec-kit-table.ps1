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
    if ($manifest.schemaVersion -notin @(1, 2) -or $manifest.tableSha256 -cne $hash) { throw 'Publication checksum mismatch.' }
    $header = if ($manifest.schemaVersion -eq 1) { '| Level | Öffentliches GitHub-Repository | Gestartet | Ausgeführt | Abschluss belegt |' }
        else { '| Level | Öffentliches GitHub-Repository / Gruppe | Gestartet | Ausgeführt | Abschluss belegt | Manuell | Autonom seriell | Autonom parallel | Gemischt | Nicht eindeutig belegt |' }
    if (-not $table.Contains($header) -or
        $table.Contains('<!--') -or $table -match '<script|<iframe') { throw 'Invalid table contract.' }
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
