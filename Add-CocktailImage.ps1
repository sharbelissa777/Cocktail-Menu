<#
.SYNOPSIS
    Adds a cocktail image to the repo, pushes it to GitHub, and wires the URL
    into index.html for the matching cocktail.

.EXAMPLE
    .\Add-CocktailImage.ps1 -Name "Aperol Spritz" -Image "C:\Users\User\Downloads\aperol.png"

.EXAMPLE
    # generate + place the file, but review before pushing
    .\Add-CocktailImage.ps1 -Name "Negroni" -Image ".\negroni.jpg" -NoPush
#>
param(
    [Parameter(Mandatory = $true)] [string] $Name,
    [Parameter(Mandatory = $true)] [string] $Image,
    [switch] $NoPush
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$indexPath = Join-Path $repo "index.html"
$ghUser = "sharbelissa777"
$ghRepo = "Cocktail-Menu"
$branch = "main"

# --- 1. Validate inputs --------------------------------------------------
if (-not (Test-Path $Image))     { throw "Image file not found: $Image" }
if (-not (Test-Path $indexPath)) { throw "index.html not found at: $indexPath" }

# --- 2. Build a clean filename from the cocktail name --------------------
$slug = ($Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
$ext  = [IO.Path]::GetExtension($Image).ToLower()
if ($ext -eq ".jpeg") { $ext = ".jpg" }
if ([string]::IsNullOrWhiteSpace($ext)) { $ext = ".png" }
$fileName = "$slug$ext"

$imagesDir = Join-Path $repo "images"
if (-not (Test-Path $imagesDir)) { New-Item -ItemType Directory -Path $imagesDir | Out-Null }
$dest = Join-Path $imagesDir $fileName
Copy-Item -Path $Image -Destination $dest -Force
Write-Host "Copied image -> images/$fileName" -ForegroundColor Green

# --- 3. Build the raw GitHub URL -----------------------------------------
$url = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$branch/images/$fileName"

# --- 4. Patch the imageUrl for this cocktail in index.html ---------------
$content = [IO.File]::ReadAllText($indexPath)
$q = [char]34
$pattern = '(?s)(' + $q + 'name' + $q + '\s*:\s*' + $q + [regex]::Escape($Name) + $q + '.*?' + $q + 'imageUrl' + $q + '\s*:\s*' + $q + ')[^' + $q + ']*(' + $q + ')'
$rx = [regex]$pattern
$replacement = '${1}' + $url + '${2}'
$new = $rx.Replace($content, $replacement, 1)

if ($new -eq $content) {
    throw "Could not find a cocktail named '$Name' (or its imageUrl) in index.html. Check the exact spelling."
}

# Bump DATA_VERSION so the menu auto-reloads from the file (no localStorage.clear needed)
$stamp = (Get-Date -Format "yyyy-MM-dd-HHmmss")
$new = [regex]::Replace($new, '(const DATA_VERSION = ")[^"]*(")', ('${1}' + $stamp + '${2}'), 1)

# Write back as UTF-8 WITHOUT BOM (avoids breaking the HTML)
[IO.File]::WriteAllText($indexPath, $new, (New-Object Text.UTF8Encoding($false)))
Write-Host "Updated index.html imageUrl for '$Name' (DATA_VERSION -> $stamp)" -ForegroundColor Green
Write-Host "  -> $url"

# --- 5. Commit & push ----------------------------------------------------
Push-Location $repo
try {
    git add "images/$fileName" "index.html" | Out-Null
    git commit -m "Add image for $Name" | Out-Null
    Write-Host "Committed." -ForegroundColor Green
    if ($NoPush) {
        Write-Host "Skipped push (-NoPush). Run 'git push' when ready." -ForegroundColor Yellow
    } else {
        git push
        Write-Host "Pushed to GitHub. Image will be live in ~1 minute." -ForegroundColor Green
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "NOTE: the live menu reads cocktails from your browser's localStorage." -ForegroundColor Cyan
Write-Host "      To see this image, open in a browser with cleared storage, or" -ForegroundColor Cyan
Write-Host "      run localStorage.clear() in the console (F12) and refresh." -ForegroundColor Cyan
