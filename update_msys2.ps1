<#
  Code by MSP-Greg
  Updates Actions Windows images MSYS2 packages, also adding common build tools.
  Exits on error, sets ENV['Create7z'] equal to 'yes' if an updated 7z file
  needs to be created and uploaded.
#>

$dash = "$([char]0x2500)"
$line = $($dash * 40)
$yel  = "`e[93m"
$grn  = "`e[92m"
$rst  = "`e[0m"

function Run-Check($msg, $cmd) {
  Write-Host "`n$yel$line $msg$rst"
  if (!$cmd) { $cmd = $msg }
  iex $cmd
  if ($LastExitCode -and $LastExitCode -ne 0) { exit 1 }
}

$current_pkgs = $(pacman -Q | grep -v ^mingw-w64- | sort) -join '`n'

Run-Check 'pacman -Syyuu --noconfirm'
taskkill /f /fi "MODULES eq msys-2.0.dll"

Write-Host 'pacman --noconfirm -Syuu (2nd pass)'
Run-Check 'pacman --noconfirm -Syuu (2nd pass)' 'pacman -Syuu  --noconfirm'
taskkill /f /fi "MODULES eq msys-2.0.dll"

$pkgs = 'autoconf-wrapper autogen automake-wrapper bison diffutils libtool m4 make patch texinfo texinfo-tex compression'
Run-Check "Install MSYS2 packages`n$pkgs" "pacman -S --noconfirm --needed --noprogressbar $pkgs"

Run-Check 'Clean packages' 'pacman -Scc --noconfirm'

$updated_pkgs = $(pacman -Q | grep -v ^mingw-w64- | sort) -join '`n'

if ($current_pkgs -eq $updated_pkgs) {
  echo "Create7z=no"      | Out-File -FilePath $env:GITHUB_PATH -Append
  echo "`n$grn** No update needed **$rst`n"
} else {
  echo "Create7z=yes" | Out-File -FilePath $env:GITHUB_PATH -Append
  echo "`n$grn** Creating and Uploading MSYS2 tools 7z **$rst`n"
}
