<#
.SYNOPSIS
Copies the production server's data down to this computer.

.DESCRIPTION
A file is copied when the server's copy is newer than the one here, or when
this computer does not have it. Files that are newer here are left alone,
and files that only exist here are never deleted.

What is copied: qb_data/, outputs/, the source caches (*_cache.json) and
merge-debug.json. Never config.properties, .gitea-token, the program, or
the server's publish clone (qb_data/publish-clone) or any other git repo.

Needs PowerShell 7, plus the ssh.exe and tar.exe that come with Windows.
The files come down as one compressed stream (zstd when the server has it,
otherwise gzip), so the copy is much smaller than the data.

ssh is started twice: once for the file list and once for the copy. If your
key has a passphrase, load it into ssh-agent first so you are not asked twice.

.PARAMETER DryRun
List what would be copied, copy nothing.

.PARAMETER Yes
Do not ask before copying. Without it, the copy still starts on its own
unless some files here are newer than the server's.

.PARAMETER ProdHost
user@host to sign in to.

.PARAMETER ProdDir
The program's folder on the server.

.PARAMETER LocalDir
The folder to copy into. Defaults to the repo this script is in.

.PARAMETER Ssh
The ssh program to use.

.EXAMPLE
pwsh tool/pull-prod-data.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  [string]$ProdHost = $(if ($env:PROD_HOST) { $env:PROD_HOST } else { 'david@192.168.2.41' }),
  [string]$ProdDir = $(if ($env:PROD_DIR) { $env:PROD_DIR } else { '/home/david/Applications/Starsector_Mod_Repo_Scraper' }),
  [string]$LocalDir = $(if ($env:LOCAL_DIR) { $env:LOCAL_DIR } else { Split-Path -Parent $PSScriptRoot }),
  [string]$Ssh = $(if ($env:SSH) { $env:SSH } else { 'ssh' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$message) {
  Write-Host "Error: $message" -ForegroundColor Red
  exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 7) { Fail 'This needs PowerShell 7 (pwsh), not Windows PowerShell 5.' }

# Windows' own tar. A GNU tar from Git earlier on the PATH would read "F:\..."
# as a remote host name.
$tar = if ($IsWindows) { Join-Path $env:SystemRoot 'System32\tar.exe' } else { 'tar' }
if (-not (Get-Command $Ssh -ErrorAction SilentlyContinue)) { Fail "$Ssh is not installed." }

$LocalDir = (Resolve-Path $LocalDir).Path
$utf8 = [Text.UTF8Encoding]::new($false)

# A job running here would be writing to the same files.
if (Test-Path (Join-Path $LocalDir 'qb_data/scraper.lock')) {
  Fail 'A scraper job is running on this computer (qb_data/scraper.lock exists). Stop it first.'
}

function Start-Program([string]$file, [string[]]$arguments, [switch]$WriteIn, [switch]$ReadOut) {
  $info = [Diagnostics.ProcessStartInfo]::new($file)
  foreach ($a in $arguments) { $info.ArgumentList.Add($a) }
  $info.UseShellExecute = $false
  $info.RedirectStandardInput = [bool]$WriteIn
  $info.RedirectStandardOutput = [bool]$ReadOut
  if ($ReadOut) { $info.StandardOutputEncoding = $utf8 }
  [Diagnostics.Process]::Start($info)
}

# For use inside single quotes in a bash command.
$remoteDir = "'" + $ProdDir.Replace("'", "'\''") + "'"

# The listing script runs under bash whatever the login shell is. It is sent
# base64-encoded so no quoting can go wrong on the way. One line per file:
# "<modified time in seconds> <size> <path>". The lock file is left out; it
# only means something on the machine that wrote it. The server's publish
# clone is left out too: it is a git repo, git makes its files read-only, so
# tar cannot replace them here, and a git repo copied file by file is broken
# anyway. A publish from this computer makes its own clone.
$listScript = @"
cd $remoteDir || exit 3
if [ -e qb_data/scraper.lock ]; then echo LOCKED; cat qb_data/scraper.lock; exit 0; fi
if command -v zstd >/dev/null 2>&1; then echo ZSTD; else echo GZIP; fi
found=()
for p in qb_data outputs *_cache.json merge-debug.json; do [ -e "`$p" ] && found+=("`$p"); done
[ `${#found[@]} -eq 0 ] && exit 0
find "`${found[@]}" -type f ! -path qb_data/scraper.lock ! -path 'qb_data/publish-clone/*' ! -path '*/.git/*' -printf '%T@ %s %p\n'
"@
$listB64 = [Convert]::ToBase64String($utf8.GetBytes($listScript.Replace("`r`n", "`n")))

Write-Host "Reading the file list on $ProdHost..."
$proc = Start-Program $Ssh @($ProdHost, "echo $listB64 | base64 -d | bash") -ReadOut
$remoteText = $proc.StandardOutput.ReadToEnd()
$proc.WaitForExit()
if ($proc.ExitCode -ne 0) { Fail "Could not read the file list from ${ProdHost}:$ProdDir." }

$remoteLines = $remoteText.Split("`n", [StringSplitOptions]::RemoveEmptyEntries)
if ($remoteLines.Count -gt 0 -and $remoteLines[0] -eq 'LOCKED') {
  Write-Host 'A job is running on the server right now:'
  $remoteLines | Select-Object -Skip 1 | ForEach-Object { Write-Host $_ }
  Fail 'Try again once it has finished, or the copy may catch files half-written.'
}
$compressor = $remoteLines[0]
if ($remoteLines.Count -lt 2) { Fail "The server has none of the data folders in $ProdDir." }

# The files here, keyed by path with forward slashes. Whole seconds only: tar
# keeps no more than that, and the two file systems store fractions differently.
$local = [Collections.Generic.Dictionary[string, long[]]]::new([StringComparer]::Ordinal)
function Add-LocalFile([IO.FileInfo]$file) {
  $path = [IO.Path]::GetRelativePath($LocalDir, $file.FullName).Replace('\', '/')
  if ($path -eq 'qb_data/scraper.lock') { return }
  $seconds = [DateTimeOffset]::new($file.LastWriteTimeUtc).ToUnixTimeSeconds()
  $local[$path] = @($seconds, $file.Length)
}
$root = [IO.DirectoryInfo]::new($LocalDir)
foreach ($folder in 'qb_data', 'outputs') {
  $dir = [IO.DirectoryInfo]::new((Join-Path $LocalDir $folder))
  if ($dir.Exists) {
    foreach ($f in $dir.EnumerateFiles('*', [IO.SearchOption]::AllDirectories)) { Add-LocalFile $f }
  }
}
foreach ($pattern in '*_cache.json', 'merge-debug.json') {
  foreach ($f in $root.EnumerateFiles($pattern)) { Add-LocalFile $f }
}

# Pick the files to copy: missing here, newer on the server, or the same
# second but a different size (the server's copy wins a tie).
$want = [Collections.Generic.List[string]]::new()
$newerHere = [Collections.Generic.List[string]]::new()
$new = 0; $updated = 0; [long]$bytes = 0
for ($i = 1; $i -lt $remoteLines.Count; $i++) {
  $parts = $remoteLines[$i].Split(' ', 3)
  if ($parts.Count -lt 3) { continue }
  $seconds = [long]$parts[0].Split('.')[0]
  $size = [long]$parts[1]
  $path = $parts[2]
  $here = $null
  if (-not $local.TryGetValue($path, [ref]$here)) {
    $new++
  } elseif ($seconds -gt $here[0] -or ($seconds -eq $here[0] -and $size -ne $here[1])) {
    $updated++
  } else {
    if ($seconds -lt $here[0]) { $newerHere.Add($path) }
    continue
  }
  $want.Add($path)
  $bytes += $size
}

Write-Host ('{0} new, {1} newer on the server, {2} newer here (kept), {3:N1} MB to copy' -f `
    $new, $updated, $newerHere.Count, ($bytes / 1MB))
if ($newerHere.Count -gt 0) {
  Write-Host 'Newer here, so not copied:'
  $newerHere | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
  if ($newerHere.Count -gt 20) { Write-Host "  ...and $($newerHere.Count - 20) more" }
}
if ($want.Count -eq 0) {
  Write-Host 'Nothing to copy. This computer is up to date.'
  exit 0
}

if ($DryRun) {
  Write-Host 'Would copy:'
  $want | ForEach-Object { Write-Host "  $_" }
  exit 0
}

# Files newer here mean this computer has data of its own. Keeping those while
# taking the server's other files can leave a mix that does not agree (say, a
# local mod-ids.json beside the server's catalog), so ask first. Otherwise
# the copy only brings this computer up to the server, and starts at once.
# The LLM test report is a one-off trial that nothing else reads, so a newer
# one here is no reason to ask.
$worthAsking = @($newerHere | Where-Object { $_ -ne 'qb_data/llm-test-output.json' })
if ($worthAsking.Count -gt 0 -and -not $Yes) {
  $answer = Read-Host "Copy $($want.Count) files from the server and keep the $($newerHere.Count) newer here? [y/N]"
  if ($answer -notin 'y', 'Y', 'yes') { Write-Host 'Nothing copied.'; exit 0 }
}

Write-Host "Copying $($want.Count) files..."
# The file list goes up to the server and the files come back as one
# compressed tar stream, which Windows' tar unpacks as it arrives. tar keeps
# each file's modified time, so the next run compares correctly.
# --keep-newer-files is a second guard in case a local file changed while
# this was running.
$pack = if ($compressor -eq 'ZSTD') { 'zstd -1 -T0 -q -c' } else { 'gzip -1 -c' }
$sender = Start-Program $Ssh @($ProdHost, "cd $remoteDir && tar -cf - --verbatim-files-from -T - | $pack") -WriteIn -ReadOut
$unpacker = Start-Program $tar @('-xf', '-', '--keep-newer-files', '-C', $LocalDir) -WriteIn

# The list is written in the background: the server starts sending files
# before it has read the whole list, and both sides must keep moving.
$listBytes = $utf8.GetBytes(($want -join "`n") + "`n")
$listStream = [IO.MemoryStream]::new($listBytes)
$listTask = $listStream.CopyToAsync($sender.StandardInput.BaseStream)
$listClosed = $false

$from = $sender.StandardOutput.BaseStream
$to = $unpacker.StandardInput.BaseStream
$buffer = [byte[]]::new(1MB)
[long]$received = 0
$clock = [Diagnostics.Stopwatch]::StartNew()
$lastShown = -1
while ($true) {
  $read = $from.ReadAsync($buffer, 0, $buffer.Length)
  while (-not $read.Wait(200)) {
    if (-not $listClosed -and $listTask.IsCompleted) { $sender.StandardInput.Close(); $listClosed = $true }
  }
  if (-not $listClosed -and $listTask.IsCompleted) { $sender.StandardInput.Close(); $listClosed = $true }
  $n = $read.Result
  if ($n -eq 0) { break }
  try { $to.Write($buffer, 0, $n) } catch { break }
  $received += $n
  $tenth = [int]($clock.Elapsed.TotalSeconds * 2)
  if ($tenth -ne $lastShown) {
    $lastShown = $tenth
    $rate = $received / 1MB / [Math]::Max($clock.Elapsed.TotalSeconds, 0.001)
    Write-Host -NoNewline ("`r  {0:N1} MB received ({1:N1} MB/s)   " -f ($received / 1MB), $rate)
  }
}
$to.Close()
$sender.WaitForExit()
$unpacker.WaitForExit()
Write-Host ("`r  {0:N1} MB received in {1:N0} s          " -f ($received / 1MB), $clock.Elapsed.TotalSeconds)

if ($sender.ExitCode -ne 0 -or $unpacker.ExitCode -ne 0) {
  Fail 'The copy did not finish. Files already copied are kept; run it again to fetch the rest.'
}
Write-Host "Done. Copied $($want.Count) files into $LocalDir."
