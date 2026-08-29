# =====================================================================
#  PowerShell 7 Profile — cleaned, deduped, modernized
# =====================================================================

#region ---------------- Network / System Info ----------------
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }
function myip { Invoke-RestMethod -Uri "http://ifconfig.me" }
function getip { Invoke-RestMethod -Uri "https://api64.ipify.org?format=json" }
function flushdns { Clear-DnsClientCache; Write-Host "DNS has been flushed" -ForegroundColor Green }
function refreshenv {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Environment PATH refreshed." -ForegroundColor Green
}
function sysinfo { Get-ComputerInfo | Format-Table -AutoSize }
function uptime {
    try {
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)
            $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
        } else {
            $lastBoot = (Get-Uptime -Since).ToString("$dateFormat $timeFormat")
            $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss") + " [$lastBoot]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray
        $u = (Get-Date) - $bootTime
        Write-Host ("Uptime: {0}d {1}h {2}m {3}s" -f $u.Days,$u.Hours,$u.Minutes,$u.Seconds) -ForegroundColor Blue
    } catch { Write-Error "Failed to get uptime: $_" }
}
#endregion

#region ---------------- Admin / Elevation ----------------
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
Set-Alias -Name su -Value admin
#endregion

#region ---------------- Profile Management ----------------
function reload-profile { . $PROFILE; Write-Host "Profile reloaded." -ForegroundColor Green }

function Edit-Profile {
    if (Get-Command code -ErrorAction SilentlyContinue) { code $PROFILE }
    else { notepad $PROFILE }
}
Set-Alias -Name ep -Value Edit-Profile

function Update-Profile {
    Write-Host "Reloading local profile..." -ForegroundColor Cyan
    . $PROFILE
    Write-Host "Done. (Hook this up to a remote gist/repo URL if you want auto-pull updates.)" -ForegroundColor Green
}

function Update-PowerShell {
    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $current = $PSVersionTable.PSVersion.ToString()
        $latest = (Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest").tag_name.TrimStart('v')
        if ([version]$current -lt [version]$latest) {
            Write-Host "Updating PowerShell $current -> $latest..." -ForegroundColor Yellow
            winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
            Write-Host "Updated. Restart your terminal." -ForegroundColor Green
        } else {
            Write-Host "PowerShell is up to date ($current)." -ForegroundColor Green
        }
    } catch { Write-Error "Failed to check PowerShell updates: $_" }
}
#endregion

#region ---------------- File / Text Utilities ----------------
function unzip {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Destination = (Get-Location).Path
    )
    $full = if (Test-Path $File) { (Resolve-Path $File).Path }
            else { (Get-ChildItem -Path (Get-Location) -Filter $File -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
    if (-not $full) { Write-Error "File not found: $File"; return }
    Write-Host "Extracting $full -> $Destination" -ForegroundColor Cyan
    Expand-Archive -Path $full -DestinationPath $Destination -Force
}
function zip { param($src, $dest) Compress-Archive -Path $src -DestinationPath $dest }

function hb {
    if ($args.Length -eq 0) { Write-Error "No file path specified."; return }
    $FilePath = $args[0]
    if (-not (Test-Path $FilePath)) { Write-Error "File path does not exist."; return }
    $Content = Get-Content $FilePath -Raw
    try {
        $response = Invoke-RestMethod -Uri "http://bin.christitus.com/documents" -Method Post -Body $Content -ErrorAction Stop
        $url = "http://bin.christitus.com/$($response.key)"
        Set-Clipboard $url
        Write-Output "$url copied to clipboard."
    } catch { Write-Error "Failed to upload document: $_" }
}

function grep($regex, $dir) {
    if ($dir) { Get-ChildItem $dir | Select-String $regex; return }
    $input | Select-String $regex
}
function sed($file, $find, $replace) { (Get-Content $file).replace("$find", $replace) | Set-Content $file }
function which($name) { Get-Command $name | Select-Object -ExpandProperty Definition }
function export($name, $value) { Set-Item -Force -Path "env:$name" -Value $value }
function pkill($name) { Get-Process $name -ErrorAction SilentlyContinue | Stop-Process }
function pgrep($name) { Get-Process $name }
function killapp { param($name) Stop-Process -Name $name -Force -ErrorAction SilentlyContinue }
function k9 { Stop-Process -Name $args[0] -ErrorAction SilentlyContinue }

function head { param($Path, $n = 10) Get-Content $Path -Head $n }
function tail { param($Path, $n = 10) Get-Content $Path -Tail $n }
function touch {
    param([Parameter(Mandatory)][string]$File)
    if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $File | Out-Null }
}
function nf { param($name) New-Item -ItemType File -Path . -Name $name }
function mkcd { param($dir) New-Item -ItemType Directory -Path $dir -Force | Out-Null; Set-Location $dir }

function ff {
    param([Parameter(Mandatory)][string]$Name)
    if (Get-Command fd -ErrorAction SilentlyContinue) { fd $Name }
    else { Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue | Select-Object FullName }
}

function df { Get-Volume }
function jsonpretty { param($jsonPath) Get-Content $jsonPath | ConvertFrom-Json | ConvertTo-Json -Depth 10 }
function csvtojson { param($csvPath) Import-Csv $csvPath | ConvertTo-Json -Depth 5 }
function backup { param($file) Copy-Item $file "$file.bak" }
function batchrename { param($folder, $pattern) Get-ChildItem $folder | Rename-Item -NewName { $_.Name -replace $pattern } }
function note { param($text) Add-Content -Path "$env:USERPROFILE\Documents\notes.txt" -Value $text }
Set-Alias getnote Get-Content
function lastdl { Invoke-Item (Get-ChildItem "$env:USERPROFILE\Downloads" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
function watchfolder { param($folder) Register-ObjectEvent -InputObject (Get-Item $folder) -EventName "Changed" -Action { Write-Host "Folder changed: $folder" -ForegroundColor Green } }

function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path
    if (-not (Test-Path $fullPath)) { Write-Host "Error: '$fullPath' does not exist." -ForegroundColor Red; return }
    $item = Get-Item $fullPath
    $parentPath = if ($item.PSIsContainer) { $item.Parent.FullName } else { $item.DirectoryName }
    $shell = New-Object -ComObject 'Shell.Application'
    $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)
    if ($shellItem) { $shellItem.InvokeVerb('delete'); Write-Host "Moved '$fullPath' to Recycle Bin." -ForegroundColor Green }
    else { Write-Host "Error: could not trash '$fullPath'." -ForegroundColor Red }
}
#endregion

#region ---------------- Modern ls (eza) / cat (bat) ----------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function la { eza -l --icons --group-directories-first }
    function ll { eza -la --icons --group-directories-first }
    function lt { eza --tree --icons --level=2 }
} else {
    function la { Get-ChildItem | Format-Table -AutoSize }
    function ll { Get-ChildItem -Force | Format-Table -AutoSize }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Option AllScope -Force
}
#endregion

#region ---------------- Navigation Shortcuts ----------------
function docs {
    $d = [Environment]::GetFolderPath("MyDocuments"); if (-not $d) { $d = "$HOME\Documents" }
    Set-Location -Path $d
}
function dtop {
    $d = [Environment]::GetFolderPath("Desktop"); if (-not $d) { $d = "$HOME\Desktop" }
    Set-Location -Path $d
}
function go { param($path) Set-Location -Path $path }
#endregion

#region ---------------- Zoxide (z) + Custom Shortcuts ----------------
if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    Write-Host "zoxide not found. Installing via winget..." -ForegroundColor Yellow
    winget install -e --id ajeetdsouza.zoxide --accept-package-agreements --accept-source-agreements
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # zoxide init binds 'z' as an ALIAS -> aliases beat functions in lookup order,
    # so we must remove it before defining our own 'z' function with subcommands.
    Remove-Item Alias:z -ErrorAction SilentlyContinue

    # Seed common folders so plain fuzzy 'z <fuzzy text>' works even without visiting them first
    $__zoxideSeeds = @(
        "E:\Downloads\WinTweaks",
        "E:\Downloads\WinTweaks\Wintool",
        "$HOME\Documents",
        "$HOME\Downloads",
        "$HOME\Desktop"
    )
    foreach ($p in $__zoxideSeeds) { if (Test-Path $p) { zoxide add "$p" 2>$null } }

    function z {
        param([Parameter(ValueFromRemainingArguments = $true)]$Args)
        switch ($Args[0]) {
            'tweaks'   { Set-Location "E:\Downloads\WinTweaks";           return }
            'wintool'  { Set-Location "E:\Downloads\WinTweaks\Wintool";   return }
            'docs'     { Set-Location "$HOME\Documents";                 return }
            'dl'       { Set-Location "$HOME\Downloads";                 return }
            'home'     { Set-Location "$HOME\Desktop";                   return }
            'myfolder' { Set-Location "$HOME\Desktop\Desktop";           return }
            default    { __zoxide_z @Args }
        }
    }
}
#endregion

#region ---------------- Git Shortcuts ----------------
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gpush { git push }
function gpull { git pull }
function gcl { git clone "$args" }
function gcom { git add .; git commit -m "$args" }
function lazyg { git add .; git commit -m "$args"; git push }
function g { __zoxide_z github }
#endregion

#region ---------------- Winget Shortcuts ----------------
function wins  { winget install --accept-package-agreements --accept-source-agreements @args }
function wlist { winget list @args }
function wls   { winget search @args }
function wrm   { winget uninstall @args }
function wupg  { winget upgrade --all --accept-package-agreements --accept-source-agreements }
function updateapps { winget upgrade --all --accept-package-agreements --accept-source-agreements }
#endregion

#region ---------------- Vivetool ----------------
function vive  { vivetool /enable /id:$args }
function vived { vivetool /disable /id:$args }
function viver { vivetool /reset /id:$args }
function viveq { vivetool /query | Select-String $args }
#endregion

#region ---------------- Power / Misc ----------------
function fastshutdown { Stop-Computer -Force }
function fastrestart { Restart-Computer -Force }
function restartps { pwsh -NoExit }
function rusb { shutdown /r /fw /t 0 }   # reboot straight to UEFI firmware settings
function shutdownin { param($minutes) Start-Sleep -Seconds ($minutes * 60); Stop-Computer -Force }
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }
function history { Get-History | Sort-Object -Property ExecutionCount -Descending }

function New-Array {
    param([string]$VarName, [string[]]$Items)
    $arrayString = $Items -join '","'
    Invoke-Expression "`$$VarName = @(`"$arrayString`")"
}
Set-Alias +var New-Array
#endregion

#region ---------------- WinUtil ----------------
function winutil { irm https://christitus.com/win | iex }
function winutildev {
    if (Get-Command -Name "WinUtilDev_Override" -ErrorAction SilentlyContinue) { WinUtilDev_Override }
    else { irm https://christitus.com/windev | iex }
}
#endregion

#region ---------------- Game Launcher Engine ----------------
function Start-GameExe {
    param([string]$Folder, [string[]]$Preferred)
    if (-not (Test-Path $Folder)) { Write-Error "Folder not found: $Folder"; return }
    foreach ($p in $Preferred) {
        $f = Get-ChildItem -Path $Folder -Filter $p -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { Start-Process -FilePath $f.FullName; return }
    }
    $exclude = @('dxsetup.exe','vcredist','unins','pbsetup.exe','pbsvc.exe','ReShade_Setup.exe','steamcmd.exe','steamerrorreporter.exe','7za.exe')
    $all = Get-ChildItem -Path $Folder -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $n = $_.Name.ToLower(); -not ($exclude | ForEach-Object { $n -like "*$_*" })
    } | Select-Object -First 1
    if ($all) { Start-Process -FilePath $all.FullName } else { Write-Error "No suitable exe found in $Folder" }
}

function Start-Game {
    param([string[]]$Folders, [string[]]$Preferred)
    $folder = $Folders | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $folder) { Write-Error "None of these folders exist: $($Folders -join ', ')"; return }
    Start-GameExe -Folder $folder -Preferred $Preferred
}

function bo3 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops III',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops III'
) -Preferred @('t7x.exe','BlackOps3.exe','BlackOps3ServerInstaller\UnrankedServer\boiii.exe') }

function blackops3 {
    $folder = 'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops III'
    if (Test-Path $folder) { Set-Location -Path $folder; Start-Process explorer -ArgumentList $folder }
    else { Write-Error "Folder not found: $folder" }
}

function bo4 { Start-Game -Folders @('E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops 4') -Preferred @('Launch Project BO4.exe','BlackOps4.exe') }
function bo2 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops 2',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops 2'
) -Preferred @('plutonium.exe','BlackOps2.exe') }
function bo1 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Black Ops'
) -Preferred @('plutonium.exe','BlackOps.exe') }
function waw { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - World At War',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - World At War'
) -Preferred @('plutonium.exe','CoDWaW.exe') }
function mw3 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Modern Warfare 3 (2011)',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Modern Warfare 3 (2011)'
) -Preferred @('plutonium.exe','iw5mp.exe') }
function mw2 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Modern Warfare 2',
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Modern Warfare 2\Call of Duty Modern Warfare 2',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Modern Warfare 2'
) -Preferred @('iw4mp.exe') }
function cod4 { Start-Game -Folders @(
    'E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty 4 - Modern Warfare',
    'F:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty 4 - Modern Warfare'
) -Preferred @('iw3mp.exe') }
function coddeluxe { Start-Game -Folders @('E:\Games\HydraGamesLauncher\CallofDutyCollection\DownloadedGames\Call of Duty - Deluxe Edition\Call of Duty Deluxe Edition') -Preferred @('CoDMP.exe','CoDSP.exe') }
#endregion

#region ---------------- PSReadLine ----------------
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'; Parameter = '#98FB98'; Operator = '#FFB6C1'
        Variable = '#DDA0DD'; String = '#FFDAB9'; Number = '#B0E0E6'
        Type = '#F0E68C'; Comment = '#D3D3D3'; Keyword = '#8367c7'; Error = '#FF6347'
    }
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    -not ($sensitive | Where-Object { $line -match $_ })
}

function Set-PredictionSource {
    if (Get-Command -Name "Set-PredictionSource_Override" -ErrorAction SilentlyContinue) {
        Set-PredictionSource_Override
    } else {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -MaximumHistoryCount 10000
    }
}
Set-PredictionSource

# fzf-powered history / dir search (Ctrl+R reverse search, Ctrl+T file finder, Alt+C cd finder)
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Pretty icons for Get-ChildItem-based output
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}
#endregion

#region ---------------- Argument Completers ----------------
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm' = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
#endregion

#region ---------------- Prompt (oh-my-posh) ----------------
if (Get-Command -Name "Get-Theme_Override" -ErrorAction SilentlyContinue) {
    Get-Theme_Override
} else {
    oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
}
#endregion

#region ---------------- Help ----------------
function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Update-Profile$($PSStyle.Reset) - Reloads your local profile.
$($PSStyle.Foreground.Green)Update-PowerShell$($PSStyle.Reset) - Checks/updates PowerShell via winget.
$($PSStyle.Foreground.Green)Edit-Profile / ep$($PSStyle.Reset) - Opens profile in VSCode (or Notepad fallback).

$($PSStyle.Foreground.Cyan)Zoxide$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)z tweaks$($PSStyle.Reset)   -> E:\Downloads\WinTweaks
$($PSStyle.Foreground.Green)z wintool$($PSStyle.Reset)  -> E:\Downloads\WinTweaks\Wintool
$($PSStyle.Foreground.Green)z docs$($PSStyle.Reset)     -> Documents
$($PSStyle.Foreground.Green)z dl$($PSStyle.Reset)       -> Downloads
$($PSStyle.Foreground.Green)z home$($PSStyle.Reset)     -> Desktop
$($PSStyle.Foreground.Green)z myfolder$($PSStyle.Reset) -> Desktop\Desktop
$($PSStyle.Foreground.Green)z <text>$($PSStyle.Reset)   -> normal fuzzy zoxide jump

$($PSStyle.Foreground.Cyan)Git$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
gs, ga, gc, gpush, gpull, gcl, gcom, lazyg, g (-> github dir)

$($PSStyle.Foreground.Cyan)Winget$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
wls (search), wins (install), wlist (list), wrm (uninstall), wupg/updateapps (upgrade all)

$($PSStyle.Foreground.Cyan)Files / Text$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
la, ll, lt (eza-powered listing), cat (bat if installed), ff, touch, head, tail, unzip, zip,
grep, sed, which, trash, nf, mkcd, hb, jsonpretty, csvtojson, backup, batchrename

$($PSStyle.Foreground.Cyan)System$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
sysinfo, uptime, myip, getip, flushdns, refreshenv, killapp, pkill, pgrep, k9,
fastshutdown, fastrestart, restartps, rusb, shutdownin

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' anytime to see this again.
"@
    Write-Host $helpText
}
#endregion

#region ---------------- Custom Overrides ----------------
if (Test-Path "$PSScriptRoot\CTTcustom.ps1") {
    . "$PSScriptRoot\CTTcustom.ps1"
}
#endregion

Write-Host "$($PSStyle.Foreground.Yellow)Profile loaded. Use 'Show-Help' to see all commands.$($PSStyle.Reset)"