#Requires -Version 7
<#
.SYNOPSIS
Prueft dauerhafte Profil-A11Y-Vertraege. / Tests durable profile accessibility contracts.
.DESCRIPTION
Offline checks cover stable navigation, heading structure, badge colors and
the deterministic, escaped MOTD generator. They do not replace assistive-tech tests.
Offline-Pruefungen ersetzen keine praktische Screenreader- oder Plattformabnahme.
.EXAMPLE
pwsh -NoProfile -File .github/scripts/test-profile-accessibility.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$readme = [IO.File]::ReadAllText((Join-Path $root 'README.md'))
if (-not $readme.StartsWith('<div lang="de">') -or $readme -notmatch '<div lang="en">\s+Welcome to my GitHub profile') { throw 'Missing profile language boundaries.' }
if ([regex]::Matches($readme, '<h1\b').Count -ne 1) { throw 'Expected one README main heading.' }
$targets = @([regex]::Matches($readme, '<h[23] id="(profile-[a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value })
$links = @([regex]::Matches($readme, '\]\(#user-content-(profile-[a-z0-9-]+)\)') | ForEach-Object { $_.Groups[1].Value })
if ($targets.Count -ne 15 -or $links.Count -ne 15 -or @($targets | Select-Object -Unique).Count -ne 15) { throw 'Missing or duplicate navigation targets.' }
for ($index = 0; $index -lt $links.Count; $index++) {
    if ($links[$index] -cne $targets[$index]) { throw 'TOC order or target mismatch.' }
}
$images = [regex]::Matches($readme, '!\[([^\]]*)\]\((https://img\.shields\.io/[^)]+)\)')
if ($images.Count -ne 36) { throw 'Unexpected technology badge inventory.' }
foreach ($image in $images) {
    if ([string]::IsNullOrWhiteSpace($image.Groups[1].Value) -or $image.Groups[1].Value -ceq 'Domain' -or
        $image.Groups[2].Value -notmatch '-334155\?' -or $image.Groups[2].Value -match 'logoColor=black') { throw 'Incomplete badge alternative or contrast regression.' }
}
if ($readme.Contains('img.shields.io/badge/Topic-') -or $readme -notmatch 'Inventarisierung / <span lang="en">Inventory</span>') { throw 'Project metadata must remain actual equivalent text.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('profile-a11y-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $scratch
try {
    $target = Join-Path $scratch 'README.md'; $messages = Join-Path $scratch 'messages.txt'
    $original = "before`r`n<!-- MOTD:START -->old<!-- MOTD:END -->`r`nafter"
    [IO.File]::WriteAllText($target, $original)
    [IO.File]::WriteAllText($messages, 'Deutsch < & > || English < & >')
    $generator = Join-Path $PSScriptRoot 'update-motd.ps1'
    & pwsh -NoProfile -File $generator -Date 2026-11-12 -Readme $target -Messages $messages -CheckOnly
    if ($LASTEXITCODE -ne 1 -or [IO.File]::ReadAllText($target) -cne $original) { throw 'MOTD CheckOnly modified bytes.' }
    & pwsh -NoProfile -File $generator -Date 2026-11-12 -Readme $target -Messages $messages -WhatIf
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($target) -cne $original) { throw 'MOTD preview modified bytes.' }
    & pwsh -NoProfile -File $generator -Date 2026-11-12 -Readme $target -Messages $messages
    if ($LASTEXITCODE -ne 0) { throw 'MOTD update failed.' }
    $updated = [IO.File]::ReadAllText($target)
    if (-not $updated.StartsWith("before`r`n") -or -not $updated.EndsWith("`r`nafter")) { throw 'MOTD changed surrounding bytes.' }
    $block = [xml][regex]::Match($updated, '<blockquote>[\s\S]*?</blockquote>').Value
    if ($block.blockquote.p[1].lang -cne 'de' -or $block.blockquote.p[2].lang -cne 'en' -or
        $block.blockquote.p[1].InnerText -cne 'Deutsch < & >' -or $block.blockquote.p[2].InnerText -cne 'English < & >') { throw 'MOTD escaping or language mismatch.' }
    & pwsh -NoProfile -File $generator -Date 2026-11-12 -Readme $target -Messages $messages -CheckOnly
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($target) -cne $updated) { throw 'MOTD not deterministic.' }
    foreach ($invalid in @('missing markers', ($updated + '<!-- MOTD:START -->'), '<!-- MOTD:END --><!-- MOTD:START -->')) {
        [IO.File]::WriteAllText($target, $invalid)
        & pwsh -NoProfile -File $generator -Date 2026-11-12 -Readme $target -Messages $messages 2>$null
        if ($LASTEXITCODE -ne 2 -or [IO.File]::ReadAllText($target) -cne $invalid) { throw 'Invalid MOTD markers accepted.' }
    }
    Write-Host 'PASS: profile language, headings, 15 stable targets, 36 high-contrast badge alternatives, escaped/idempotent MOTD and no-write preview.'
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force }
exit 0
