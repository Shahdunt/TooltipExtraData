[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [ValidateSet("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security", "Performance", "Stability", "Improved")]
    [string]$Type = "Changed",

    [string[]]$Message = @(),

    [string]$ChangelogPath = "CHANGELOG.md",

    [string]$TocPath = "TooltipExtraData.toc",

    [switch]$AllowDuplicateMessages,

    [switch]$NoDiff
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-ProjectPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location).Path $Path
}

function Assert-FileExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontro el archivo: $Path"
    }
}

function Get-Newline {
    param([string]$Text)

    if ($Text.Contains("`r`n")) {
        return "`r`n"
    }

    return "`n"
}

function Get-ReleaseEntry {
    param(
        [string]$Version,
        [string]$Date,
        [string]$Type,
        [string[]]$Message,
        [string]$Newline
    )

    $lines = @("## [$Version] - $Date", "", "### $Type")

    foreach ($item in $Message) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $lines += "- $($item.Trim())"
        }
    }

    return ($lines -join $Newline)
}

function Normalize-ChangelogMessage {
    param([string]$Message)

    return ($Message.Trim() -replace '\s+', ' ').ToLowerInvariant()
}

function Get-ChangelogBulletMessages {
    param([string]$Text)

    $messages = @()
    foreach ($match in [regex]::Matches($Text, "(?m)^\s*-\s+(?<message>.+?)\s*$")) {
        $messages += $match.Groups["message"].Value
    }

    return $messages
}

function Assert-NoDuplicateMessages {
    param(
        [string]$ExistingText,
        [string]$CandidateText
    )

    $existing = @{}
    foreach ($message in Get-ChangelogBulletMessages -Text $ExistingText) {
        $normalized = Normalize-ChangelogMessage -Message $message
        if (-not $existing.ContainsKey($normalized)) {
            $existing[$normalized] = $message.Trim()
        }
    }

    $duplicates = @()
    foreach ($message in Get-ChangelogBulletMessages -Text $CandidateText) {
        $normalized = Normalize-ChangelogMessage -Message $message
        if ($existing.ContainsKey($normalized)) {
            $duplicates += $existing[$normalized]
        }
    }

    if ($duplicates.Count -gt 0) {
        $uniqueDuplicates = $duplicates | Select-Object -Unique
        $lines = @("CHANGELOG.md ya contiene estos cambios:")
        foreach ($duplicate in $uniqueDuplicates) {
            $lines += "- $duplicate"
        }
        $lines += "Usa -AllowDuplicateMessages si quieres repetirlos intencionalmente."
        throw ($lines -join [Environment]::NewLine)
    }
}

function Get-FirstReleaseIndex {
    param([string]$Text)

    $match = [regex]::Match($Text, "(?m)^## \[\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?\]")
    if (-not $match.Success) {
        throw "No se encontro ninguna seccion de version en CHANGELOG.md."
    }

    return $match.Index
}

function Ensure-UnreleasedAtTop {
    param(
        [string]$Text,
        [string]$Newline
    )

    if ($Text -match "(?m)^## \[Unreleased\]") {
        return $Text
    }

    return Insert-ReleaseAtTop -Text $Text -Entry "## [Unreleased]" -Newline $Newline
}

function Insert-ReleaseAtTop {
    param(
        [string]$Text,
        [string]$Entry,
        [string]$Newline
    )

    $index = Get-FirstReleaseIndex -Text $Text
    $prefix = $Text.Substring(0, $index).TrimEnd()
    $rest = $Text.Substring($index).TrimStart()

    return $prefix + ($Newline * 2) + $Entry + ($Newline * 2) + $rest.TrimEnd() + $Newline
}

function Convert-UnreleasedToRelease {
    param(
        [string]$Text,
        [string]$Version,
        [string]$Date,
        [string]$Newline
    )

    $pattern = "(?ms)^## \[Unreleased\]\s*(?<body>.*?)(?=^## \[|\z)"
    $match = [regex]::Match($Text, $pattern)

    if (-not $match.Success) {
        return $null
    }

    $body = $match.Groups["body"].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($body)) {
        throw "La seccion [Unreleased] existe, pero no tiene cambios. Usa -Message para crear una entrada nueva."
    }

    $entry = "## [$Version] - $Date" + ($Newline * 2) + $body
    $withoutUnreleased = $Text.Remove($match.Index, $match.Length).TrimEnd() + $Newline

    $withRelease = Insert-ReleaseAtTop -Text $withoutUnreleased -Entry $entry -Newline $Newline
    return Ensure-UnreleasedAtTop -Text $withRelease -Newline $Newline
}

if ($Version -notmatch '^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$') {
    throw "La version '$Version' no parece SemVer. Ejemplo valido: 1.4.4"
}

$resolvedChangelogPath = Resolve-ProjectPath -Path $ChangelogPath
$resolvedTocPath = Resolve-ProjectPath -Path $TocPath

Assert-FileExists -Path $resolvedChangelogPath
Assert-FileExists -Path $resolvedTocPath

$date = Get-Date -Format "yyyy-MM-dd"
$changelog = Get-Content -LiteralPath $resolvedChangelogPath -Raw
$newline = Get-Newline -Text $changelog

if ($changelog -match "(?m)^## \[$([regex]::Escape($Version))\]") {
    throw "CHANGELOG.md ya contiene una entrada para la version $Version."
}

if ($Message.Count -gt 0) {
    $entry = Get-ReleaseEntry -Version $Version -Date $date -Type $Type -Message $Message -Newline $newline

    if (-not $AllowDuplicateMessages) {
        Assert-NoDuplicateMessages -ExistingText $changelog -CandidateText $entry
    }

    $newChangelog = Insert-ReleaseAtTop -Text $changelog -Entry $entry -Newline $newline
}
else {
    if (-not $AllowDuplicateMessages) {
        $unreleasedMatch = [regex]::Match($changelog, "(?ms)^## \[Unreleased\]\s*(?<body>.*?)(?=^## \[|\z)")
        if ($unreleasedMatch.Success) {
            $publishedChangelog = $changelog.Remove($unreleasedMatch.Index, $unreleasedMatch.Length)
            Assert-NoDuplicateMessages -ExistingText $publishedChangelog -CandidateText $unreleasedMatch.Groups["body"].Value
        }
    }

    $newChangelog = Convert-UnreleasedToRelease -Text $changelog -Version $Version -Date $date -Newline $newline

    if ($null -eq $newChangelog) {
        throw "No hay seccion [Unreleased]. Usa -Message para crear una entrada nueva."
    }
}

$toc = Get-Content -LiteralPath $resolvedTocPath -Raw
if ($toc -notmatch "(?m)^## Version:\s*.+$") {
    throw "No se encontro la linea '## Version:' en $TocPath."
}

$newToc = [regex]::Replace($toc, "(?m)^## Version:\s*.+$", "## Version: $Version", 1)

[System.IO.File]::WriteAllText($resolvedChangelogPath, $newChangelog, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($resolvedTocPath, $newToc, [System.Text.UTF8Encoding]::new($false))

Write-Host "Release preparada: $Version ($date)"
Write-Host "Actualizados:"
Write-Host "- $ChangelogPath"
Write-Host "- $TocPath"

if (-not $NoDiff) {
    Write-Host ""
    git diff -- $ChangelogPath $TocPath
}
