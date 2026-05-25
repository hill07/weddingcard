$ErrorActionPreference = "Stop"

$root         = Split-Path -Parent $PSCommandPath
$configPath   = Join-Path $root "wedding-config.json"
$templatePath = Join-Path $root "assets\index-template.js"
$outputPath   = Join-Path $root "assets\index-C78NrZjj.js"

if (-not (Test-Path $configPath))   { throw "Missing: wedding-config.json" }
if (-not (Test-Path $templatePath)) { throw "Missing: assets\index-template.js" }

try {
    $config = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
} catch {
    Write-Host ""
    Write-Host "ERROR: wedding-config.json is not valid JSON." -ForegroundColor Red
    Write-Host "Common issues: missing/extra commas, unmatched quotes, stray characters." -ForegroundColor Yellow
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$template  = [System.IO.File]::ReadAllText($templatePath, $utf8NoBom)

function Get-Field($obj, $path) {
    $cur = $obj
    foreach ($p in ($path -split '\.')) {
        if ($null -eq $cur -or $null -eq $cur.$p) {
            throw "wedding-config.json is missing field: $path"
        }
        $cur = $cur.$p
    }
    $s = [string]$cur
    if ([string]::IsNullOrEmpty($s)) { throw "wedding-config.json field '$path' is empty" }
    return $s
}

# Build a JS string literal that re-encodes safely (handles quotes, backslashes, control chars).
function To-JsStringLiteral([string]$s) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('"')
    foreach ($c in $s.ToCharArray()) {
        $code = [int]$c
        switch ($code) {
            0x08 { [void]$sb.Append('\b') }
            0x09 { [void]$sb.Append('\t') }
            0x0A { [void]$sb.Append('\n') }
            0x0C { [void]$sb.Append('\f') }
            0x0D { [void]$sb.Append('\r') }
            0x22 { [void]$sb.Append('\"') }
            0x5C { [void]$sb.Append('\\') }
            default {
                if ($code -lt 0x20) {
                    [void]$sb.AppendFormat('\u{0:x4}', $code)
                } else {
                    [void]$sb.Append($c)
                }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

$bride = Get-Field $config 'couple.bride'
$groom = Get-Field $config 'couple.groom'

# Curly apostrophe used in the original "You're Invited" string.
$sq = [char]0x2019

# Each pair: an exact quoted source string in the template => the new value (plain text).
# Order does not matter; we sort longest-first below.
$pairs = @(
    # --- Couple combined & standalone ---
    @{ src = '"Diksha & Kabir"'; tgt = "$bride & $groom" }
    @{ src = '"Kabir & Diksha"'; tgt = "$groom & $bride" }
    @{ src = '"Diksha"';         tgt = $bride }
    @{ src = '"Kabir"';          tgt = $groom }

    # --- Bride family ---
    @{ src = '"Daughter of Smt. Shikha & Shri Tarun Agarwal"'; tgt = "Daughter of $(Get-Field $config 'bride.mother') & $(Get-Field $config 'bride.father')" }
    @{ src = '"Smt. Shikha"';                                  tgt = (Get-Field $config 'bride.mother') }
    @{ src = '"Shri Tarun Agarwal"';                           tgt = (Get-Field $config 'bride.father') }

    # --- Groom family ---
    @{ src = '"Mrs. Smita & Mr. Pawan Agarwal"';        tgt = (Get-Field $config 'groom.parents') }
    @{ src = '"Mrs. Samita Agarwal"';                   tgt = (Get-Field $config 'groom.mother') }
    @{ src = '"Mr. Pawn Agarwal"';                      tgt = (Get-Field $config 'groom.father') }
    @{ src = '"Smt. Lalita Devi & Shri. Ravi Agarwal"'; tgt = (Get-Field $config 'groom.blessings') }

    # --- Date ---
    @{ src = '"June 05, 2026"'; tgt = (Get-Field $config 'date.full') }
    @{ src = '"2026"';          tgt = (Get-Field $config 'date.year') }
    @{ src = '"June"';          tgt = (Get-Field $config 'date.month') }
    @{ src = '"FRI"';           tgt = (Get-Field $config 'date.weekday') }
    @{ src = '"WED"';           tgt = (Get-Field $config 'date.weekday2') }

    # --- Venue ---
    @{ src = '"Uttar Garden Lawn"';                                                                                  tgt = (Get-Field $config 'venue.name') }
    @{ src = '"A-12,Amaara Farms, Mandir Rd, Main Chhatarpur Rd, Bhatti Kalan, New Delhi, Delhi 110074"';            tgt = (Get-Field $config 'venue.address') }

    # --- Event taglines ---
    @{ src = '"A playful morning of mehendi and cultural festivities"'; tgt = (Get-Field $config 'events.mehendiTagline') }
    @{ src = '"A playful night of sangeet and cultural festivities"';   tgt = (Get-Field $config 'events.sangeetTagline') }
    @{ src = '"A playful Night with friends and cultural Activities"';  tgt = (Get-Field $config 'events.cocktailTagline') }
    @{ src = '"Because meeting two soul requires twice the fun"';       tgt = (Get-Field $config 'events.receptionTagline') }

    # --- Labels ---
    @{ src = "`"You${sq}re Invited`"";                tgt = (Get-Field $config 'labels.youAreInvited') }
    @{ src = '"Tap to open your invitation"';         tgt = (Get-Field $config 'labels.tapToOpen') }
    @{ src = '"Save the date"';                       tgt = (Get-Field $config 'labels.saveTheDate') }
    @{ src = '"Scratch to reveal"';                   tgt = (Get-Field $config 'labels.scratchToReveal') }
    @{ src = '"Awaiting Your Noble Presence"';        tgt = (Get-Field $config 'labels.awaitingPresence') }
    @{ src = '"Cordialy invite you to attend the"';   tgt = (Get-Field $config 'labels.cordiallyInvite') }
    @{ src = '"With the blessings Of"';               tgt = (Get-Field $config 'labels.withBlessings') }
    @{ src = '"Wedding of their son"';                tgt = (Get-Field $config 'labels.weddingOfTheirSon') }
    @{ src = '"With immense joy and love"';           tgt = (Get-Field $config 'labels.withImmenseJoy') }
    @{ src = '"The Families"';                        tgt = (Get-Field $config 'labels.theFamilies') }
    @{ src = '"Wedding Events"';                      tgt = (Get-Field $config 'labels.weddingEvents') }
    @{ src = '"Where We Celebrate"';                  tgt = (Get-Field $config 'labels.whereWeCelebrate') }
    @{ src = '"Dress code"';                          tgt = (Get-Field $config 'labels.dressCode') }
    @{ src = '"Get Directions"';                      tgt = (Get-Field $config 'labels.getDirections') }
    @{ src = '"||Shree Ganeshaya Namah||"';           tgt = (Get-Field $config 'labels.ganeshMantra') }
)

# Sort longest source first so "Daughter of Smt. Shikha & Shri Tarun Agarwal" is replaced
# before "Smt. Shikha", etc.
$pairs = $pairs | Sort-Object { -$_.src.Length }

# Two-pass substitution via unique tokens, so that a target value can never accidentally
# match another source string in pass 2.
$output   = $template
$tokenMap = [ordered]@{}
$i        = 0

foreach ($p in $pairs) {
    if (-not $output.Contains($p.src)) {
        Write-Warning "Source not found in template (skipped): $($p.src)"
        continue
    }
    $token = "__WC_TOKEN_${i}__"
    $tokenMap[$token] = To-JsStringLiteral $p.tgt
    $output = $output.Replace($p.src, $token)
    $i++
}

foreach ($entry in $tokenMap.GetEnumerator()) {
    $output = $output.Replace($entry.Key, $entry.Value)
}

[System.IO.File]::WriteAllText($outputPath, $output, $utf8NoBom)

Write-Host ""
Write-Host "Bundle regenerated: assets\index-C78NrZjj.js" -ForegroundColor Green
Write-Host "$i field(s) applied from wedding-config.json"
