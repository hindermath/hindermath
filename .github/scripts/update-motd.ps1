#Requires -Version 7
<#
.SYNOPSIS
Aktualisiert die zweisprachige Profil-MOTD. / Updates the bilingual profile MOTD.
.DESCRIPTION
Selects the existing UTC-day message deterministically and replaces exactly one
marker pair with escaped, language-marked HTML. Preserves all surrounding bytes.
Waehlt die Nachricht deterministisch und erhaelt alle Bytes ausserhalb der Marker.
.PARAMETER Date
UTC date yyyy-MM-dd; defaults to today. / UTC-Datum; Standard ist heute.
.PARAMETER Readme
Target README. / Ziel-README.
.PARAMETER Messages
Existing bilingual message list. / Bestehende zweisprachige Nachrichtenliste.
.PARAMETER CheckOnly
Detect drift without writing. / Drift ohne Schreibzugriff pruefen.
.EXAMPLE
pwsh -NoProfile -File .github/scripts/update-motd.ps1 -CheckOnly
.EXAMPLE
pwsh -NoProfile -File .github/scripts/update-motd.ps1 -Date 2026-11-12 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Date = [DateTime]::UtcNow.ToString('yyyy-MM-dd'),
    [string]$Readme = (Join-Path $PSScriptRoot '../../README.md'),
    [string]$Messages = (Join-Path $PSScriptRoot '../motd/messages.txt'),
    [switch]$CheckOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    $null = [DateTime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $entries = @([IO.File]::ReadAllLines($Messages) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($entries.Count -eq 0) { throw 'No MOTD entries found.' }
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Date)))
    $index = [Convert]::ToInt64($digest.Substring(0, 8), 16) % $entries.Count
    $parts = $entries[$index].Split(' || ', 2, [StringSplitOptions]::None)
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) { throw 'Invalid bilingual MOTD entry.' }
    $de = [Net.WebUtility]::HtmlEncode($parts[0])
    $en = [Net.WebUtility]::HtmlEncode($parts[1])
    $begin = '<!-- MOTD:START -->'; $end = '<!-- MOTD:END -->'
    $content = [IO.File]::ReadAllText($Readme)
    if ([regex]::Matches($content, [regex]::Escape($begin)).Count -ne 1 -or
        [regex]::Matches($content, [regex]::Escape($end)).Count -ne 1) { throw 'Exactly one MOTD marker pair is required.' }
    $start = $content.IndexOf($begin, [StringComparison]::Ordinal)
    $finish = $content.IndexOf($end, [StringComparison]::Ordinal)
    if ($finish -le $start) { throw 'Reversed MOTD markers.' }
    $block = @($begin, '<blockquote>', '<p><strong>MOTD / <span lang="en">Message of the Day</span></strong></p>',
        "<p lang=`"de`">$de</p>", "<p lang=`"en`">$en</p>", '</blockquote>', $end) -join "`n"
    $updated = $content.Substring(0, $start) + $block + $content.Substring($finish + $end.Length)
    if ($updated -ceq $content) { Write-Host 'CURRENT: language-marked MOTD.'; exit 0 }
    if ($CheckOnly) { Write-Host 'DRIFT: MOTD.'; exit 1 }
    if ($PSCmdlet.ShouldProcess($Readme, 'Update language-marked MOTD')) { [IO.File]::WriteAllText($Readme, $updated, [Text.UTF8Encoding]::new($false)) }
    Write-Host "UPDATED: MOTD index $index."
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 2
}
