param(
    [Parameter(Mandatory = $true)][string]$AssetPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$repository = 'Wrathtide/ProjectZomboid-Extinction'
$tag = 'v1.1.0'
$expectedRemote = 'https://github.com/' + $repository + '.git'
$remote = (git -C $projectRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -ne $expectedRemote) {
    throw 'Nieoczekiwane repozytorium docelowe.'
}
$commit = (git -C $projectRoot rev-parse HEAD).Trim()
$tagCommit = (git -C $projectRoot rev-parse "$tag^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or $tagCommit -ne $commit) {
    throw 'Tag wydania nie wskazuje bieżącego commitu.'
}
$asset = Get-Item -LiteralPath $AssetPath
if ($asset.Name -ne 'Extinction-1.1.0.zip') { throw 'Nieoczekiwana nazwa pakietu.' }
$credential = @{}
$headers = @{}
$oldTerminalPrompt = $env:GIT_TERMINAL_PROMPT
$oldInteractive = $env:GCM_INTERACTIVE
try {
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'Never'
    $lines = "protocol=https`nhost=github.com`npath=$repository.git`n`n" | git credential fill
    if ($LASTEXITCODE -ne 0) { throw 'Brak zapisanej autoryzacji GitHub.' }
    foreach ($line in $lines) {
        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) { $credential[$parts[0]] = $parts[1] }
    }
    if (-not $credential.password) { throw 'Nie uzyskano autoryzacji GitHub.' }
    $headers = @{
        Authorization = 'Bearer ' + $credential.password
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2026-03-10'
    }
    $api = 'https://api.github.com/repos/' + $repository
    $repo = Invoke-RestMethod -Uri $api -Headers $headers
    if ($repo.visibility -ne 'public') { throw 'Repozytorium nie jest publiczne; nie zmieniono jego widoczności.' }
    $remoteMain = Invoke-RestMethod -Uri "$api/commits/main" -Headers $headers
    if ($remoteMain.sha -ne $commit) { throw 'GitHub main nie wskazuje zweryfikowanego wydania.' }
    $remoteTag = Invoke-RestMethod -Uri "$api/git/ref/tags/$tag" -Headers $headers
    if ($remoteTag.object.type -ne 'commit' -or $remoteTag.object.sha -ne $commit) {
        throw 'Tag na GitHub nie wskazuje zweryfikowanego commitu.'
    }
    $release = $null
    try {
        $release = Invoke-RestMethod -Uri "$api/releases/tags/$tag" -Headers $headers
    } catch {
        if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
    }
    $notes = Get-Content -LiteralPath (Join-Path $projectRoot 'docs/RELEASE_1.1.0.md') -Raw
    foreach ($name in @('UPDATE_1.1_NATURAL_STARVATION.md', 'STEAM_DESCRIPTION.txt')) {
        $notes = $notes.Replace("($name)", "(https://github.com/$repository/blob/$tag/docs/$name)")
    }
    $payload = @{
        tag_name = $tag
        target_commitish = $commit
        name = 'Extinction 1.1.0 — Natural Extinction & Animal Hunting'
        body = $notes
        draft = $false
        prerelease = $false
        make_latest = 'true'
    } | ConvertTo-Json -Depth 4
    if ($null -eq $release) {
        $release = Invoke-RestMethod -Uri "$api/releases" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
    } else {
        $release = Invoke-RestMethod -Uri "$api/releases/$($release.id)" -Method Patch -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
    }
    $existingAsset = @($release.assets | Where-Object name -eq $asset.Name)
    if ($existingAsset.Count -eq 0) {
        $upload = 'https://uploads.github.com/repos/' + $repository + '/releases/' + $release.id + '/assets?name=' + [Uri]::EscapeDataString($asset.Name)
        $uploaded = Invoke-RestMethod -Uri $upload -Method Post -Headers $headers -ContentType 'application/zip' -InFile $asset.FullName
    } else {
        $uploaded = $existingAsset[0]
        $digest = 'sha256:' + (Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($uploaded.digest -ne $digest) { throw 'Istniejący pakiet ma inną sumę; nie został nadpisany.' }
    }
    $description = @{ description = 'Apocalypse-relative extinction for Project Zomboid B42: fixed timeline or optional natural extinction, independent animal hunting, persistent remains, legacy-save protection.' } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri $api -Method Patch -Headers $headers -ContentType 'application/json' -Body $description
    $verified = Invoke-RestMethod -Uri "$api/releases/tags/$tag" -Headers $headers
    if ($verified.draft -or $verified.prerelease -or @($verified.assets | Where-Object name -eq $asset.Name).Count -ne 1) {
        throw 'Weryfikacja publicznego wydania nie powiodła się.'
    }
    $verified | Select-Object html_url, tag_name, draft, prerelease
    $uploaded | Select-Object name, size, digest, browser_download_url
} finally {
    $credential.Clear()
    $headers.Clear()
    $lines = $null
    $env:GIT_TERMINAL_PROMPT = $oldTerminalPrompt
    $env:GCM_INTERACTIVE = $oldInteractive
}
