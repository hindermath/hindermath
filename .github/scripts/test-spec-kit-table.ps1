#Requires -Version 7
<#
.SYNOPSIS
Offline-Test des Profilimports. / Offline profile import test.
.DESCRIPTION
Checks checksum failures, marker validation, idempotency and preservation of MOTD.
Prüft Hashfehler, Markierungen, Idempotenz und MOTD-Erhalt in einem temporären Verzeichnis.
.EXAMPLE
pwsh -NoProfile -File .github/scripts/test-spec-kit-table.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('profile-statistics-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $scratch
try {
    $table = "Datenstand: 2026-09-10T00:00:00Z`n`n| Level | Öffentliches GitHub-Repository | Gestartet | Ausgeführt | Abschluss belegt |`n|---|---|---:|---:|---:|`n| 0 | example | 1 | 1 | 1 |`n"
    [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $table)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($table))).ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $scratch 'publication.json'), (@{schemaVersion=1;tableSha256=$hash} | ConvertTo-Json))
    $readme = Join-Path $scratch 'README.md'
    $original = "MOTD unchanged`r`n<!-- public-speckit-runs:begin -->`nold`n<!-- public-speckit-runs:end -->`r`nFooter unchanged"
    [IO.File]::WriteAllText($readme, $original)
    $script = Join-Path $PSScriptRoot 'update-spec-kit-table.ps1'
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme -CheckOnly
    if ($LASTEXITCODE -ne 1 -or [IO.File]::ReadAllText($readme) -cne $original) { throw 'CheckOnly wrote or did not detect drift.' }
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme
    if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
    $updated = [IO.File]::ReadAllText($readme)
    if (-not $updated.StartsWith("MOTD unchanged`r`n") -or -not $updated.EndsWith("`r`nFooter unchanged")) { throw 'Surrounding bytes changed.' }
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme -CheckOnly
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($readme) -cne $updated) { throw 'Not idempotent.' }
    [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $table + 'tampered')
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme 2>$null
    if ($LASTEXITCODE -ne 2 -or [IO.File]::ReadAllText($readme) -cne $updated) { throw 'Checksum failure mutated README.' }
    [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $table)
    foreach ($bad in @('missing markers', '<!-- public-speckit-runs:end --><!-- public-speckit-runs:begin -->', ($original + '<!-- public-speckit-runs:begin -->'))) {
        [IO.File]::WriteAllText($readme, $bad)
        & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme 2>$null
        if ($LASTEXITCODE -ne 2 -or [IO.File]::ReadAllText($readme) -cne $bad) { throw 'Bad marker validation failed.' }
    }
    $v2 = $table.Replace('| Level | Öffentliches GitHub-Repository | Gestartet | Ausgeführt | Abschluss belegt |', '| Level | Öffentliches GitHub-Repository / Gruppe | Gestartet | Ausgeführt | Abschluss belegt | Manuell | Autonom seriell | Autonom parallel | Gemischt | Nicht eindeutig belegt |')
    [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $v2)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($v2))).ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $scratch 'publication.json'), (@{schemaVersion=2;tableSha256=$hash} | ConvertTo-Json))
    [IO.File]::WriteAllText($readme, $original)
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme
    if ($LASTEXITCODE -ne 0 -or -not ([IO.File]::ReadAllText($readme)).Contains($v2.TrimEnd())) { throw 'V2 export was not imported byte-for-byte.' }
    $v3 = $v2.Replace('Nicht eindeutig belegt |', 'Nicht eindeutig belegt | Beschleunigungsfaktor (Repo-Schätzung) |')
    [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $v3)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($v3))).ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $scratch 'publication.json'), (@{schemaVersion=3;tableSha256=$hash} | ConvertTo-Json))
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme
    if ($LASTEXITCODE -ne 0 -or -not ([IO.File]::ReadAllText($readme)).Contains($v3.TrimEnd())) { throw 'V3 export was not imported byte-for-byte.' }
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme -CheckOnly
    if ($LASTEXITCODE -ne 0) { throw 'V3 import not idempotent.' }
    $headings = @($v3.Split("`n")[2].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    $columns = ($headings | ForEach-Object { '<th scope="col">' + $_ + '</th>' }) -join ''
    $html = '<div lang="de"><table aria-label="Spec-Kit-Statistik" lang="de"><caption>Spec-Kit-Statistik</caption><thead><tr>' + $columns + '</tr></thead><tbody><tr><td>0</td><th scope="row"><a href="https://github.com/example/source">source</a></th>' + ('<td>0</td>' * 8) + '<td>nicht berechenbar</td></tr></tbody></table></div>'
    function Set-AccessibleFixture {
        param([string]$Content, [string]$Format = 'accessible-html-v1')
        [IO.File]::WriteAllText((Join-Path $scratch 'table.md'), $Content)
        $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Content))).ToLowerInvariant()
        [IO.File]::WriteAllText((Join-Path $scratch 'publication.json'), (@{schemaVersion=3;tableFormat=$Format;tableSha256=$digest} | ConvertTo-Json))
    }
    Set-AccessibleFixture $html
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme
    if ($LASTEXITCODE -ne 0 -or -not ([IO.File]::ReadAllText($readme)).Contains($html)) { throw 'Semantic table import failed.' }
    $safeReadme = [IO.File]::ReadAllText($readme)
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme -CheckOnly
    if ($LASTEXITCODE -ne 0 -or -not $safeReadme.StartsWith("MOTD unchanged`r`n") -or -not $safeReadme.EndsWith("`r`nFooter unchanged")) { throw 'Semantic table import changed surrounding bytes or is not idempotent.' }
    foreach ($invalid in @(
        $html.Replace('scope="row"', 'scope="col"'),
        $html.Replace('<td>0</td>', '<td onclick="alert(1)">0</td>'),
        $html.Replace('https://github.com/example/source', 'javascript:alert(1)'),
        $html.Replace('<caption>', '<iframe>'),
        $html.Replace('Gestartet', 'Wrong header'),
        $html.Replace('lang="de"', 'lang="en"'),
        ('<!DOCTYPE div [<!ENTITY proof SYSTEM "https://example.invalid/secret">]>' + $html)
    )) {
        Set-AccessibleFixture $invalid
        & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme 2>$null
        if ($LASTEXITCODE -ne 2 -or [IO.File]::ReadAllText($readme) -cne $safeReadme) { throw 'Invalid semantic table was imported or changed README.' }
    }
    Set-AccessibleFixture $html 'future-unreviewed-format'
    & pwsh -NoProfile -File $script -SourceDirectory $scratch -Readme $readme 2>$null
    if ($LASTEXITCODE -ne 2) { throw 'Unknown presentation accepted.' }
    Write-Host 'PASS: legacy and semantic table imports, no-write checks, safe HTML, checksum, languages, headers, idempotency and MOTD preservation.'
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force }
# GitHub's PowerShell wrapper propagates the last native exit code. Expected
# negative test calls must not turn a successfully completed test suite red.
exit 0
